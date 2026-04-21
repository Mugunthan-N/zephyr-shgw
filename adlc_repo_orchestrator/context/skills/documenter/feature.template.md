# Feature — Technical Document Template

<!-- 
  This template is used by the Documenter agent to generate a comprehensive
  technical document for feature/enhancement tasks completed through the ADLC pipeline.
  Aligned with: https://rently.atlassian.net/wiki/spaces/DP/pages/2301657682/Template+for+feature+task

  Instructions for the Documenter agent:
  - Replace all {{placeholder}} markers with actual values from task artefacts.
  - Write concise, factual prose for narrative sections.
  - Preserve all table structures.
  - Remove these HTML comment blocks from the final output.
  - If a section has no data, write "N/A" with a brief reason.
  - Sections marked <<before development>> should be populated from task artefacts even if filled retrospectively.
  - Sections marked <<after development>> should be populated from implementation and test artefacts.
-->

# {{title_prefix}} - {{ticket_key}}: {{feature_title}}

| Field | Value |
|-------|-------|
| **Task ID** | {{ticket_key}} |
| **Type** | Feature |
| **Status** | {{final_status}} |
| **Created** | {{created_at}} |
| **Completed** | {{completed_at}} |
| **Total Duration** | {{total_duration}} |
| **Rework Cycles** | {{rework_count}} / {{max_rework}} |

---

<!-- <<to be filled before starting the development>> -->

## 1. Description

<!-- Short description of the task and its outcome. From user_request.md and task_plan.md. -->

{{summary}}

### 1.1 User Request

<!-- Verbatim or near-verbatim reproduction of the original request. -->

> {{user_request_text}}

## 2. Impact Analysis

<!-- Modules, services, libraries, and applications impacted by this change. From design.md and task_plan.md. -->

### 2.1 Impacted Modules / Services / Libraries / Applications

{{impact_analysis}}

### 2.2 Hardware Version Compatibility

<!-- Confirm which hub versions are affected and that older versions are not broken. -->

| Hub Version | Impact | Notes |
|-------------|--------|-------|
| {{hub_version}} | {{impact_level}} | {{version_notes}} |

## 3. Development Approach

<!-- Summary of the technical and functional approach used for accomplishing the customer needs. From design.md. -->

{{development_approach}}

### 3.1 Architecture Overview

<!-- System context and how this feature fits in the overall hub architecture. -->

{{architecture_overview}}

### 3.2 Component Breakdown

<!-- Components created or modified. From design.md. -->

| Component | Type | Location | Responsibility |
|-----------|------|----------|----------------|
| {{component_name}} | {{new_or_modified}} | {{file_path}} | {{responsibility}} |

### 3.3 Key Design Decisions

<!-- Decisions made during design that influenced the implementation. -->

| Decision | Rationale | Alternatives Considered |
|----------|-----------|------------------------|
| {{decision}} | {{rationale}} | {{alternatives}} |

### 3.4 Data Models

<!-- New or modified data structures, schemas, or state representations. From design.md. -->

{{data_models}}

### 3.5 Interaction Sequences

<!-- Key scenarios with step-by-step flow. From design.md. -->

{{interaction_sequences}}

## 4. Testing Approach

<!-- Summary of the testing approach used. From test_report.md. -->

{{testing_approach}}

---

<!-- <<to be filled during or after completing development>> -->

## 5. Test Cases & Expected Results

<!-- Test cases added or updated as part of this task. From test_report.md. -->

| Test File | Test Name | Scenario | Expected Result | Status |
|-----------|-----------|----------|-----------------|--------|
| {{test_file}} | {{test_name}} | {{scenario}} | {{expected_result}} | {{status}} |

## 6. Code Coverage

<!-- Code coverage metrics before and after the change. From test_report.md. -->

**Overall Code Coverage:**
- Before: **{{coverage_before}}%**
- After: **{{coverage_after}}%**

**Individual Files:**

| File | Coverage Before | Coverage After |
|------|-----------------|----------------|
| {{file_name}} | {{file_coverage_before}}% | {{file_coverage_after}}% |

## 7. Development Summary

<!-- <<to be filled during or after completing development>> -->

### 7.1 Files Changed

#### New Files

| File | Description |
|------|-------------|
| {{new_file_path}} | {{new_file_description}} |

#### Modified Files

| File | Change Description |
|------|--------------------|
| {{mod_file_path}} | {{mod_description}} |

### 7.2 Key Implementation Details

<!-- Most important implementation decisions from IMPLEMENTATION_NOTES.md. -->

{{implementation_details}}

### 7.3 Deviations from Design

<!-- Any deviations from the original design and their justification. From IMPLEMENTATION_NOTES.md. -->

{{deviations}}

### 7.4 Database / Schema Changes

<!-- Table changes, field changes, schema changes. Note any changes to tables replicated in Archival DB. -->
<!-- For schema changes with NOT NULL constraints and default values, explicitly run migration on Archival DB. -->
<!-- Get database changes approved from the DB changes group. -->

{{db_changes}}

### 7.5 Workflows / Screens Impacted

<!-- In case of UI changes, include the browsers tested on (Safari, Firefox, Chrome). -->

{{workflows_screens_impacted}}

### 7.6 Environmental Variables

<!-- List new environment variables with sample values if any added as part of this task. -->

| Variable | Sample Value | Description |
|----------|--------------|-------------|
| {{env_var_name}} | {{sample_value}} | {{env_var_description}} |

### 7.7 API Changes

<!-- External and Internal API changes. Confirm Postman test cases updated and pushed. -->

| API | Type (Internal/External) | Change Description | Standard Followed |
|-----|--------------------------|-------------------|-------------------|
| {{api_endpoint}} | {{api_type}} | {{api_change}} | {{standard_followed}} |

### 7.8 Security

#### Threat Modelling

<!-- Threat modelling summary following the four-question approach. -->

| Question | Details |
|----------|---------|
| What are we building? | {{what_we_build}} |
| What can go wrong? | {{what_can_go_wrong}} |
| What are we going to do about it? | {{mitigation_plan}} |
| Did we do a good enough job? | {{review_effectiveness}} |

#### Secure Coding Guidelines Checklist

<!-- Items from https://rently.atlassian.net/wiki/spaces/DP/pages/2302967923 addressed for this task. -->

{{secure_coding_checklist}}

### 7.9 Performance Metrics

<!-- Response time before/after and observations (Datadog, Query Analyzer). -->
<!-- Provide load testing report if load testing was required. -->

| Metric | Before | After | Observation |
|--------|--------|-------|-------------|
| {{metric_name}} | {{before_value}} | {{after_value}} | {{observation}} |

## 8. Requirement Traceability

| Requirement ID | Description | Test(s) | Status |
|----------------|-------------|---------|--------|
| {{req_id}} | {{req_description}} | {{test_names}} | {{req_status}} |

## 9. Review

### 9.1 Review Verdict

**{{review_verdict}}**

### 9.2 Findings Summary

| Severity | Count |
|----------|-------|
| Critical | {{critical_count}} |
| Major | {{major_count}} |
| Minor | {{minor_count}} |

### 9.3 Notable Findings

<!-- Findings resolved during rework, or minor findings accepted. -->

{{notable_findings}}

## 10. Pipeline Execution Timeline

<!-- From state.yaml execution_log. -->

| Stage | Status | Started | Completed | Duration | Notes |
|-------|--------|---------|-----------|----------|-------|
| {{stage_name}} | {{stage_status}} | {{stage_started}} | {{stage_completed}} | {{stage_duration}}s | {{stage_note}} |

### 10.1 Rework History

<!-- From feedbacks/ directory. If no rework, write "No rework cycles were needed." -->

{{rework_history}}

## 11. Risks & Assumptions

### Assumptions

{{assumptions}}

### Risks

| Risk | Mitigation |
|------|------------|
| {{risk}} | {{mitigation}} |

## 12. Future Considerations

<!-- Recommendations from the review report, out-of-scope items, or technical debt introduced. -->

{{future_considerations}}

---

**I have completed unit testing, impact analysis, performance optimisation and adhered to secure coding guidelines as mentioned above and ensured that this feature is working as per the customer needs.**

---

*Generated by the ADLC Pipeline Documenter — {{generated_at}}*
