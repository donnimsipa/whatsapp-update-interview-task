# WhatsApp Patient Phone Sync — Candidate Brief

## 1. What You Will Deliver
You will complete two pieces of work:
- **Part A – Phone Update Script**: Transform the provided patient bundle by applying phone numbers from the shared Google Sheet.
- **Part B – System Design Proposal**: Describe how you would build and operate the full nightly sync service, complete with diagrams and rationale.

## 2. Context
Sphere’s maternal-health teams update patient WhatsApp numbers throughout the day in a shared sheet. The national FHIR registry must reflect those updates before outreach starts each morning. Your role is to demonstrate how you would bridge the data gap today (Part A) and how you would build the production-grade solution (Part B).

## 3. Resources Provided
- Google Sheet link: <https://docs.google.com/spreadsheets/d/1Uh6788unaWaAE1VlnbhGbWzANcf-hN3DrGQzJcxJ3Fc/edit?usp=sharing>
- Offline sheet export: `docs/interview/Whatsapp Data - Sheet.csv`
- Patient bundle JSON: `docs/interview/patients-data.json` with `patients_before_phone_update` (input) and `patients_after_phone_update` (reference structure)
- Internal notes: `docs/interview-task.md` (task overview) and this brief

## 4. Nightly Sync Expectations
- The sync must start automatically at **23:00 Asia/Jakarta** every night. Assume field officers finish data entry by 22:45.
- The job ingests all rows whose `last_updated_date` matches the current date. Each row contains the patient’s NIK (`nik_identifier`) and the latest WhatsApp phone number.
- The system must update the national FHIR server by:
  1. Searching for the patient via the NIK identifier (`Patient?identifier=https://fhir.kemkes.go.id/id/nik|<NIK>`).
  2. Updating/adding the patient’s `telecom` entry of type `phone` and use `mobile` with the WhatsApp number.
- Target throughput is **≥20,000 patient updates in ≤30 minutes** under realistic network conditions.
- Access to Google Sheets occurs via a service account; FHIR writes require an `x-api-key`. Plan for secure storage and rotation of both secrets.
- Operators need clear visibility of progress (records processed, successes, failures), alerts on critical failures, and a way to rerun the job for a given date if needed.

## 5. Part A – Phone Update Script
- Build a script/program that reads the sheet (or CSV export), normalises the phone numbers, and updates the patient resources from `patients_before_phone_update` so the resulting payload mirrors the shape of `patients_after_phone_update`.
- You can output the transformed bundle to stdout, a file, or an API simulator—document the flow.
- Clearly state any assumptions, data-cleaning rules, or edge cases you addressed.
- Include run instructions (commands, environment expectations, dependencies) so we can reproduce the result.

## 6. Part B – System Design Proposal
- Describe the production platform you would build to execute the nightly sync described above.
- Include the following artefacts:
  - **Component diagram** naming services such as scheduler/orchestrator, data ingestion workers, FHIR integration layer, persistence/cache, observability stack, and secrets management.
  - **Data-flow or sequence diagram** tracing a patient record from Google Sheets through your processing logic to the FHIR API, including retry/error branches.
  - **Operations view** outlining hosting/runtime (e.g., Cloud Run job, Kubernetes CronJob), scaling rules, configuration management, and the operator interfaces for monitoring or manual re-runs.
- In your narrative, cover:
  - Triggering the job exactly at 23:00, expected duration, and how you prevent overlapping runs.
  - Performance strategy to meet the ≥20k in ≤30 minutes requirement (feel free to propose your own optimisation techniques).
  - Idempotency approach, retry/backoff logic, and handling of partial failures or external outages.
  - Security and compliance considerations for storing credentials and transmitting patient data.
  - Monitoring/alerting signals, dashboards, and on-call runbooks.
  - Disaster recovery strategy (e.g., rerunning for a past date, replaying subsets, data reconciliation).
- State any assumptions or trade-offs you make, and note future improvements you would prioritise.

## 7. Deliverables Checklist
- Repository (public or private with access) containing:
  - Part A source code + run instructions + sample output artefact.
  - Part B design doc and diagrams.
  - Tests (if any) with execution instructions.
  - A short retrospective or assumption list summarising key decisions and open questions.
- Optional: short walkthrough video or additional notes highlighting your solution.

## 8. Evaluation Criteria
We assess both parts for:
- **Correctness**: Phone updates apply to the intended patients; design addresses required behaviours.
- **Performance & Scalability**: Part A handles the dataset efficiently; Part B explains how the nightly job scales.
- **Maintainability**: Code and docs are structured, readable, and easy to follow.
- **Reliability & Testing**: Critical logic is defensive and tested where feasible.
- **Operational Fit**: Runbooks, monitoring, and deployment considerations are realistic.

## 9. Tips
- Normalise phone numbers carefully (preserve leading zeroes, handle +62, strip formatting).
- Document assumptions instead of leaving them implicit.
- Use whatever tools you are comfortable with for diagrams and testing; just make sure outputs are in the repo.

## 10. Questions
If anything is unclear, surface the question (or your assumption) in your README and reach out through the interviewer when needed.
