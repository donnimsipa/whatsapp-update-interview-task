# Part B – System Design Proposal (Self-hosted n8n Scenario)

Design for a self-hosted n8n workflow that performs the nightly WhatsApp phone synchronization and meets the business requirements. n8n is a good fit here because it bundles the essentials (cron trigger, Google Sheets connector, HTTP/FHIR nodes) without requiring us to maintain custom cron services or bespoke connectors, and it provides a Web UI for monitoring and rerunning workflows on demand. The goal is to provide planning guidance—this document does not include a full n8n template/workflow export or low-level implementation steps.

---

## 1. Overview & Schedule
- n8n workflow runs via Cron trigger at **23:00 Asia/Jakarta** every night.
- Workflow steps: download Google Sheet as CSV → validate/normalize rows → push updates to FHIR → log results.
- A second manual trigger (Webhook or UI button) allows reruns for a specific `targetDate` parameter.
- Scheduler is configured with **concurrency guard**: only one execution at a time; reruns queue until the active run completes to avoid overlap.

---

## 2. Artefacts (stored under `diagrams/`)
1. `diagrams/component.mmd` – Mermaid component diagram covering Cron, n8n workflow, Sheets integration, queue, FHIR API, dashboards.
2. `diagrams/sequence.mmd` – Mermaid sequence diagram: Cron → download CSV → batch loop → FHIR PATCH → logging/alerts.
3. `diagrams/operations.mmd` – Mermaid operational view (hosting stack, scaling levers, observability hooks, rerun path).

Render these Mermaid files using VS Code, GitHub preview, or mermaid-cli when you need PNG/SVG exports.

---

## 3. Hosting & Scaling
- **Hosting**: Self-host n8n on a small Kubernetes cluster (e.g., 2 vCPU / 4 GB RAM). Attach persistent volume for credentials/workflows.
- **Time zone**: set container TZ or workflow Cron to `Asia/Jakarta` so 23:00 is accurate.
- **Scaling**: Nightly workflow is single-threaded, but within n8n we use `SplitInBatches` node to process up to 500 rows per batch. If throughput needs to grow, scale n8n to queue mode (BullMQ) and run multiple workers; configure batch size and parallel HTTP requests accordingly to stay within API quotas.

---

## 4. Data Sources & Security
- **Google Sheets integration**: Use the CSV export endpoint (`https://docs.google.com/spreadsheets/d/<ID>/export?format=csv&gid=<TAB>`) inside an HTTP Request node. Workflow downloads the file each run, so data is always fresh. If the sheet requires auth, switch to the n8n Google Sheets node with a service-account credential.
- **FHIR access**: HTTP Request nodes hit the FHIR server using a secured `x-api-key`. Store the key in n8n credentials (encrypted at rest) and inject it into headers at runtime.
- **Secrets**: Restrict n8n UI access with SSO/basic auth. Rotate Sheets credentials and the FHIR API key quarterly; update n8n credentials without redeploying containers.

---

## 5. Workflow Logic
1. **Cron Trigger** (23:00) sets `targetDate = today()`.
2. **HTTP Download** node fetches CSV, writes to binary data.
3. **CSV Parse** node converts to JSON rows.
4. **Function Node** filters rows to `last_updated_date == targetDate`, normalizes phone numbers (reuse Part A logic), and flags invalid entries.
5. **If Node** routes invalid rows to a DLQ path (append to review sheet, send Slack alert).
6. **SplitInBatches** loops over valid rows (200–500 per batch).
7. For each batch:
   - **HTTP GET** to `/Patient?identifier=...` (FHIR).
   - **Function** prepares telecom update, ensures idempotent hash (NIK+phone) to skip duplicates.
   - **HTTP PATCH/PUT** updates FHIR entry. Retry settings: 3 attempts, exponential backoff (2s, 4s, 8s).
8. **Merge Results** node aggregates metrics (processed/skipped/failed) and writes run summary to a “Run Status” Google Sheet or Slack channel.
9. **On Fail** branch posts alert, logs context, and marks execution as failed for rerun.

---

## 6. Performance Targets
- With batches of 200 and average API latency 150 ms, the workflow processes ~1 300 rows/minute. Increase concurrency (parallel HTTP nodes up to 5) to reach ≥20k in <30 min.
- n8n server sized with adequate CPU to handle concurrent HTTP calls; monitor resource usage and scale VM/pod if CPU >75% for sustained periods.

---

## 7. Observability
- Enable n8n **execution logs** retention (at least 30 days).
- Use Function nodes to send metrics to an external sink (Prometheus pushgateway or InfluxDB) with counts, duration, failure totals.
- Configure alerting via Slack/Email nodes when:
  - Workflow fails or exceeds 30 minutes.
  - DLQ row count > threshold (e.g., >50).
- Maintain a simple dashboard (Grafana or Google Data Studio) pulling from run-status sheet/prometheus.

---

## 8. Rerun Strategy & Idempotency
- Manual rerun: trigger the workflow via n8n UI or REST API with `targetDate` set to the previous day.
- Idempotency: compute hash of `nik + phone + date`; store in a key/value sheet or in-memory set during the run to avoid duplicate FHIR writes within the same execution.
- Failed rows land in “DLQ” Google Sheet tab for manual correction; once fixed, rerun for that date.

---

## 9. Failure Handling & DR
- **Temporary API errors**: Node retries handle transient issues; persistent failures push to DLQ and alert Ops.
- **Sheet unavailable**: Workflow logs the 4xx/5xx response, retries 3x, then fails with alert. Operators can rerun after confirming access.
- **n8n downtime**: Deploy n8n in HA (two replicas) behind load balancer; use managed DB/Redis for state if queue mode enabled. Backup credentials/workflows regularly (export JSON).
- **Disaster recovery**: Keep nightly CSV snapshots in object storage; ability to rerun for any date using stored file + rerun trigger.

---

## 10. Assumptions & Trade-offs
- Sheet remains public or at least service-account-readable; if access changes, switch to authenticated Google Sheets node.
- Single n8n instance is sufficient; heavier loads may require dedicated queue workers.
- n8n execution logs + external metrics provide enough observability; if more detail needed, integrate full APM later.
- Using CSV export avoids dependency on Sheets API quotas but assumes consistent schema; consider schema validation before processing.
- Detailed n8n node configurations, expressions, and credentials setup are **out of scope** here; the workflow will be built following this plan during implementation.

---

## 11. Future Enhancements
- Add **webhook trigger** to allow ad-hoc mid-day syncs or on-demand reruns with payload specifying date.
- Build a small **Ops dashboard** (Next.js or Retool) to visualize run history, DLQ contents, and rerun button.
- Integrate with **PagerDuty** or equivalent for structured on-call routing.
- Consider moving normalization logic to reusable code module (e.g., Node.js microservice) if rules grow complex.

---

This document stays lightweight; keep the workflow JSON, diagrams, and runbook scripts in this directory so the design remains actionable.
