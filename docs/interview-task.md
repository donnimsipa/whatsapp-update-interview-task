# WhatsApp Patient Phone Sync — Candidate Instructions

## Overview
You will complete two related deliverables:
1. **Part A – Phone Update Script**: Write a script that syncs WhatsApp numbers from the provided Google Sheet into the sample FHIR patient bundle.
2. **Part B – System Design Proposal**: Present the architecture you would build to operate the nightly sync in production, including diagrams and narrative.

Read `docs/interview/candidate-brief.md` for full context, sample payloads, and grading notes.

## Part A – Phone Update Script
- Use the Google Sheet: <https://docs.google.com/spreadsheets/d/1Uh6788unaWaAE1VlnbhGbWzANcf-hN3DrGQzJcxJ3Fc/edit?usp=sharing> (offline copy at `docs/interview/Whatsapp Data - Sheet1.csv`).
- The repository includes `docs/interview/patients-data.json` with two arrays: `patients_before_phone_update` (input) and `patients_after_phone_update` (expected structure).
- Build a script/program that reads the sheet, normalises phone numbers, and applies them to the `patients_before_phone_update` resources so the output matches the shape of `patients_after_phone_update`.
- Show how to run the script and where the resulting payload is written (e.g., stdout, file export, API call simulator).
- Document any assumptions, data-cleaning rules, or edge cases you handled.

## Part B – System Design Proposal
- Describe the production-ready platform you would build to run the nightly WhatsApp phone sync at 23:00 (Asia/Jakarta) every day.
- Include the following artefacts:
  - **Component diagram** that names each service (scheduler/orchestrator, data-ingestion worker, FHIR integration layer, storage, monitoring, secrets management, etc.).
  - **Data-flow sequence** showing how a row travels from Google Sheets through your processing pipeline into the FHIR API, including failure and retry paths.
  - **Operations view** outlining deployment targets (e.g., Cloud Run, ECS, Kubernetes), scaling rules, alerting/observability stack, and the interfaces operators use to trigger re-runs.
- In the write-up, address:
  - How the job is triggered at 23:00, how long you expect it to run, and how you keep multiple runs from overlapping.
  - Strategies for performance (processing ≥20k rows within 30 minutes) without prescribing a specific batching technique.
  - Idempotency, retry/backoff logic, and how partial failures or downstream outages are handled.
  - Configuration and credential management for Google APIs and the FHIR service, including security considerations.
  - Monitoring, logging, and alerting: which signals you collect and how you surface them to the team.
  - Disaster recovery/replay approach if the job fails mid-run or needs to be rerun for a previous date.
- Call out any assumptions, trade-offs, or future enhancements you would make with more time.

## Submission Checklist
- Fork this repository and complete both parts within your fork.
- Push the fork to your GitHub account and either keep it public or invite us with read access.
- Ensure the fork contains:
  - The Part A script plus run instructions and sample output.
  - Supporting files or exports used to generate patient data updates.
  - Part B system design materials (embed diagrams/docs in the repo or link to external artefacts from the README).
  - Automated tests (if any) and instructions to execute them.
- Surface assumptions and open questions in your README.
- Optional: Record a short walkthrough video or provide additional notes clarifying your design decisions.

## Questions
If you need clarification during the exercise, please contact us. When in doubt, make reasonable assumptions and document them.
