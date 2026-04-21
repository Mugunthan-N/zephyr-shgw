# Bug Fix — Technical Document Template

<!-- 
  This template is used by the Documenter agent to generate a comprehensive
  technical document for bug fix tasks completed through the ADLC pipeline.
  Aligned with: https://rently.atlassian.net/wiki/spaces/DP/pages/2306244905/Template+for+Production+Bug+Documentation

  Instructions for the Documenter agent:
  - Replace all {{placeholder}} markers with actual values from task artefacts.
  - Write concise, factual prose for narrative sections.
  - Preserve all table structures.
  - Remove these HTML comment blocks from the final output.
  - If a section has no data, write "N/A" with a brief reason.
-->

# {{title_prefix}} - {{ticket_key}}: {{bug_title}}

| Field | Value |
|-------|-------|
| **Task ID** | {{ticket_key}} |
| **Type** | Bug Fix |
| **Severity** | {{bug_severity}} |
| **Status** | {{final_status}} |
| **Created** | {{created_at}} |
| **Completed** | {{completed_at}} |
| **Total Duration** | {{total_duration}} |
| **Rework Cycles** | {{rework_count}} / {{max_rework}} |

---

<!-- <<to be filed during or after completing development>> -->

## 1. Description

<!-- Description of the bug behaviour. From user_request.md and task_plan.md. -->

{{summary}}

### 1.1 User Report

<!-- Verbatim or near-verbatim reproduction of the original bug report. -->

> {{user_request_text}}

## 2. Reproduction Steps

<!-- Step-by-step instructions to reproduce the reported issue. From task_plan.md. -->

{{reproduction_steps}}

## 3. Business Impact

<!-- Company-wide or selected clients impacted. Quantify if possible. From task_plan.md. -->

{{business_impact}}

## 4. Source

<!-- How the bug was discovered: client report, Datadog alert, Airbrake, QE, etc. -->

| Source | Details |
|--------|---------|
| {{source_type}} | {{source_details}} |

## 5. Root Cause

<!-- Which area of source code, rake task, background job, or execution path caused this issue. From design.md. -->

### 5.1 Investigation

<!-- How the root cause was identified. -->

{{investigation}}

### 5.2 Root Cause

<!-- Precise technical explanation of why the bug occurred. -->

{{root_cause}}

### 5.3 Affected Code

<!-- Files and functions where the bug originated. From IMPLEMENTATION_NOTES.md. -->

| File | Function / Area | Issue |
|------|-----------------|-------|
| {{source_file}} | {{function_area}} | {{issue_description}} |

## 6. Solution

<!-- How the issue is resolved: code change, data correction, configuration update, etc. From design.md and IMPLEMENTATION_NOTES.md. -->

{{solution}}

### 6.1 Solution Type

<!-- Quick fix / Permanent fix — justify the choice. -->

**{{solution_type}}**

{{solution_type_justification}}

### 6.2 Alternatives Considered

| Alternative | Reason Not Chosen |
|-------------|-------------------|
| {{alternative}} | {{reason}} |

### 6.3 Files Changed

| File | Change Description |
|------|--------------------|
| {{file_path}} | {{change_description}} |

### 6.4 Key Implementation Details

<!-- Technical details of the fix. From IMPLEMENTATION_NOTES.md. -->

{{implementation_details}}

### 6.5 Side Effects & Regression Risk

<!-- Any potential side effects of the fix. From design.md and review_report.md. -->

{{side_effects}}

## 7. Monitoring

<!-- What monitoring has been added or verified: Airbrake, Datadog, email alerts, CloudWatch, etc. -->

| Monitoring Type | Details |
|-----------------|---------|
| {{monitoring_type}} | {{monitoring_details}} |

## 8. Test Cases

<!-- Test cases added as part of this fix. From test_report.md. -->

### 8.1 Regression Tests

<!-- Tests specifically added to prevent this bug from recurring. -->

| Test File | Test Name | Validates |
|-----------|-----------|-----------|
| {{test_file}} | {{test_name}} | {{validates}} |

### 8.2 Test Summary

| Metric | Value |
|--------|-------|
| Total Tests | {{total_tests}} |
| Passed | {{passed_tests}} |
| Failed | {{failed_tests}} |
| Line Coverage | {{line_coverage}}% |
| Branch Coverage | {{branch_coverage}}% |

### 8.3 Requirement Traceability

| Requirement | Test(s) | Status |
|-------------|---------|--------|
| {{req_id}} | {{test_names}} | {{test_status}} |

## 9. Duration of Bug

<!-- How long this bug has existed in the system. Estimate based on git history, logs, or incident reports. -->

{{bug_duration}}

## 10. Resolution Time

<!-- How long it took from bug discovery to production resolution. -->

{{resolution_time}}

## 11. Review

### 11.1 Review Verdict

**{{review_verdict}}**

### 11.2 Findings Summary

| Severity | Count |
|----------|-------|
| Critical | {{critical_count}} |
| Major | {{major_count}} |
| Minor | {{minor_count}} |

### 11.3 Notable Findings

{{notable_findings}}

## 12. Pipeline Execution Timeline

<!-- From state.yaml execution_log. -->

| Stage | Status | Started | Completed | Duration | Notes |
|-------|--------|---------|-----------|----------|-------|
| {{stage_name}} | {{stage_status}} | {{stage_started}} | {{stage_completed}} | {{stage_duration}}s | {{stage_note}} |

### 12.1 Rework History

{{rework_history}}

## 13. Prevention

### 13.1 How to Prevent Recurrence

<!-- Recommendations to avoid similar bugs in the future. -->

{{prevention_recommendations}}

### 13.2 Related Areas to Inspect

<!-- Other code areas that might have the same pattern or issue. -->

{{related_areas}}

---

*Generated by the ADLC Pipeline Documenter — {{generated_at}}*
