#!/usr/bin/env bash
# =============================================================================
# ADLC Pipeline Bootstrap Script
# =============================================================================
# Creates the entire ADLC folder structure with skeleton context files.
# Run from your repository root:
#   bash adlc_bootstrap.sh
#
# What it does:
#   1. Creates adlc_repo_orchestrator/ directory tree
#   2. Generates skeleton context files with correct frontmatter
#   3. Generates pipeline.yaml with default configuration
#   4. Creates .gitkeep in workspace/
#   5. Appends workspace/ to .gitignore
#
# What it does NOT do:
#   - Copy agent files (do that separately from reference repo)
#   - Write project-specific content (that's your job)
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
BASE_DIR="adlc_repo_orchestrator"
AGENTS_DIR=".github/agents"
PROJECT_NAME="${1:-my_project}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
if [[ ! -d ".git" ]]; then
  error "Not a git repository. Run this from your repository root."
  exit 1
fi

if [[ -d "${BASE_DIR}/context" ]]; then
  warn "Context directory already exists. Existing files will NOT be overwritten."
fi

info "Bootstrapping ADLC pipeline for project: ${PROJECT_NAME}"

# ---------------------------------------------------------------------------
# Create directory tree
# ---------------------------------------------------------------------------
create_dir() {
  mkdir -p "$1"
}

create_dir "${AGENTS_DIR}"
create_dir "${BASE_DIR}/configs"
create_dir "${BASE_DIR}/context/rules"
create_dir "${BASE_DIR}/context/knowledge"
create_dir "${BASE_DIR}/context/guidelines"
create_dir "${BASE_DIR}/context/skills/planner"
create_dir "${BASE_DIR}/context/skills/requirement"
create_dir "${BASE_DIR}/context/skills/designer"
create_dir "${BASE_DIR}/context/skills/developer"
create_dir "${BASE_DIR}/context/skills/dev_testing"
create_dir "${BASE_DIR}/context/skills/reviewer"
create_dir "${BASE_DIR}/context/skills/healer"
create_dir "${BASE_DIR}/context/skills/documenter"
create_dir "${BASE_DIR}/context/skills/git_ops"
create_dir "${BASE_DIR}/workspace"

ok "Directory tree created"

# ---------------------------------------------------------------------------
# Helper: write file only if it doesn't exist
# ---------------------------------------------------------------------------
write_if_new() {
  local filepath="$1"
  local content="$2"
  if [[ -f "${filepath}" ]]; then
    warn "Skipped (exists): ${filepath}"
  else
    echo "${content}" > "${filepath}"
    ok "Created: ${filepath}"
  fi
}

# ---------------------------------------------------------------------------
# Context — Rules
# ---------------------------------------------------------------------------

write_if_new "${BASE_DIR}/context/rules/${PROJECT_NAME}_rules.md" "---
type: rule
scope: project-specific
version: \"1.0.0\"
domain: platform
agents: [all]
---

# ${PROJECT_NAME} — Project Rules

## TODO: Add your project-specific mandatory rules here.
## Follow the schema: R-<PREFIX>-<NNN>: <Rule Name>

## Example Category

### R-XX-001: Example Rule

- **Severity**: critical
- **Description**: Describe the mandatory constraint and why it matters.
- **Bad**:
  \`\`\`
  // What NOT to do
  \`\`\`
- **Good**:
  \`\`\`
  // What TO do
  \`\`\`"

# ---------------------------------------------------------------------------
# Context — Knowledge
# ---------------------------------------------------------------------------

write_if_new "${BASE_DIR}/context/knowledge/architecture.md" "---
type: knowledge
scope: project-specific
version: \"1.0.0\"
domain: architecture
agents: [all]
---

# ${PROJECT_NAME} — Architecture Overview

## System Overview
<!-- What does this system do? What is its primary purpose? -->
TODO: Describe the system.

## Startup / Boot Sequence
<!-- How does the application initialize? Entry point → config → services → ready -->
TODO: Document the startup sequence.

\`\`\`
entry_point.js
  → loads configuration
  → initializes services
  → starts listening
\`\`\`

## Layered Architecture
<!-- Diagram showing layers/tiers and their responsibilities -->
TODO: Draw the architecture layers.

\`\`\`
┌─────────────────────────────────────┐
│           Presentation              │
├─────────────────────────────────────┤
│           Business Logic            │
├─────────────────────────────────────┤
│           Data Access               │
├─────────────────────────────────────┤
│           Infrastructure            │
└─────────────────────────────────────┘
\`\`\`

## Key Design Decisions
<!-- Major architectural choices and the reasoning behind them -->
TODO: Document major decisions.

## External Integrations
<!-- What external services/APIs does the system connect to? -->
TODO: List external dependencies."

write_if_new "${BASE_DIR}/context/knowledge/modules.md" "---
type: knowledge
scope: project-specific
version: \"1.0.0\"
domain: modules
agents: [all]
---

# ${PROJECT_NAME} — Module Inventory

## Directory Map
<!-- Top-level directory tree with brief descriptions -->
TODO: Run \`tree -L 2 -d\` and annotate each directory.

\`\`\`
<your-repo>/
├── src/                  ← Source code
│   ├── controllers/      ← Request handlers
│   ├── services/         ← Business logic
│   ├── models/           ← Data models
│   └── utils/            ← Shared utilities
├── test/                 ← Test files
├── config/               ← Configuration
└── docs/                 ← Documentation
\`\`\`

## Key Files
<!-- Critical files agents should know about -->
| File | Purpose |
|------|---------|
| TODO | TODO |

## Module Dependency Graph
<!-- How major modules depend on each other -->
TODO: Document module relationships.

## Configuration Files
<!-- Where configuration lives, format, environment variables -->
TODO: Document config loading pattern."

write_if_new "${BASE_DIR}/context/knowledge/tech_stack.md" "---
type: knowledge
scope: project-specific
version: \"1.0.0\"
domain: tech-stack
agents: [all]
---

# ${PROJECT_NAME} — Tech Stack

## Runtime
- **Language**: TODO (e.g., Node.js 20, Python 3.12, Go 1.22)
- **Package Manager**: TODO (e.g., npm, pip, go modules)
- **OS/Platform**: TODO (e.g., Linux, Docker, AWS Lambda)

## Frameworks & Libraries
| Package | Version | Purpose |
|---------|---------|---------|
| TODO | TODO | TODO |

## Build Tools
- **Build**: TODO (e.g., webpack, esbuild, tsc, make)
- **Lint**: TODO (e.g., ESLint, pylint, golangci-lint)
- **Format**: TODO (e.g., Prettier, Black, gofmt)

## Testing Stack
- **Framework**: TODO (e.g., Jest, Mocha, pytest, go test)
- **Assertion**: TODO (e.g., Chai, assert, testify)
- **Mocking**: TODO (e.g., Sinon, unittest.mock, gomock)
- **Coverage**: TODO (e.g., Istanbul/nyc, coverage.py, go cover)
- **Thresholds**: TODO (e.g., 80% lines, 70% branches)

## CI/CD
- **Pipeline**: TODO (e.g., GitHub Actions, Jenkins, GitLab CI)
- **Deploy**: TODO (e.g., Kubernetes, AWS, Heroku)

## Key Constraints
<!-- Version locks, deprecated APIs, compatibility requirements -->
TODO: List constraints agents must respect."

# ---------------------------------------------------------------------------
# Context — Guidelines
# ---------------------------------------------------------------------------

write_if_new "${BASE_DIR}/context/guidelines/coding_patterns.md" "---
type: guideline
scope: project-specific
version: \"1.0.0\"
domain: coding-patterns
agents: [all]
---

# ${PROJECT_NAME} — Coding Patterns

## TODO: Document the patterns your team uses.

## Module Structure Pattern
<!-- How are files/classes/modules typically structured? -->

**Pattern**:
\`\`\`
// TODO: Show your module structure template
\`\`\`

## Error Handling Pattern
<!-- How does the project handle errors? -->

**Pattern**:
\`\`\`
// TODO: Show your error handling convention
\`\`\`

## Async Pattern
<!-- Callbacks, promises, async/await? -->

**Pattern**:
\`\`\`
// TODO: Show your async convention
\`\`\`

## Logging Pattern
<!-- How does the project log? -->

**Pattern**:
\`\`\`
// TODO: Show your logging convention
\`\`\`"

write_if_new "${BASE_DIR}/context/guidelines/naming_conventions.md" "---
type: guideline
scope: project-specific
version: \"1.0.0\"
domain: naming
agents: [all]
---

# ${PROJECT_NAME} — Naming Conventions

## Variables & Functions
- **Style**: TODO (e.g., camelCase, snake_case)
- **Boolean prefix**: TODO (e.g., is, has, can, should)

## Constants
- **Style**: TODO (e.g., UPPER_SNAKE_CASE)

## Classes / Types
- **Style**: TODO (e.g., PascalCase)

## Files & Directories
- **Style**: TODO (e.g., camelCase.js, kebab-case.ts)

## Events / Messages
- **Style**: TODO (e.g., lower_snake_case, camelCase)

## API Fields (if applicable)
- **Request/Response**: TODO (e.g., snake_case, camelCase)
- **Database columns**: TODO (e.g., snake_case)"

# ---------------------------------------------------------------------------
# Context — Skills
# ---------------------------------------------------------------------------

write_if_new "${BASE_DIR}/context/skills/planner/decomposition_patterns.md" "---
type: skill
scope: project-specific
version: \"1.0.0\"
domain: planner
agents: [planner]
---

# Planner Skills — ${PROJECT_NAME}

## Task Decomposition Patterns
<!-- How should tasks be broken down for this project? -->

### Component Areas
TODO: List the major areas of the codebase that tasks typically touch.

### Decomposition Rules
- TODO: When to create subtasks for tests
- TODO: When to create subtasks for documentation
- TODO: Scope boundaries

## Configured Tool Usage
<!-- If you have MCP servers (Jira, etc.), document when to use them -->"

write_if_new "${BASE_DIR}/context/skills/requirement/requirement_templates.md" "---
type: skill
scope: project-specific
version: \"1.0.0\"
domain: requirement
agents: [requirement]
---

# Requirement Skills — ${PROJECT_NAME}

## Standard NFRs
TODO: Define NFRs common to your project.

| Category | Requirement |
|----------|-------------|
| Performance | TODO |
| Security | TODO |
| Reliability | TODO |

## Acceptance Criteria Patterns
TODO: Document how acceptance criteria are written for your project."

write_if_new "${BASE_DIR}/context/skills/designer/design_patterns.md" "---
type: skill
scope: project-specific
version: \"1.0.0\"
domain: designer
agents: [designer]
---

# Designer Skills — ${PROJECT_NAME}

## Module Patterns
TODO: How are new modules structured in this project?

## File Placement
TODO: Where do new files go? What determines the directory?

## Architecture Decision Template
TODO: How are architecture decisions documented?"

write_if_new "${BASE_DIR}/context/skills/developer/code_patterns.md" "---
type: skill
scope: project-specific
version: \"1.0.0\"
domain: developer
agents: [developer]
---

# Developer Skills — ${PROJECT_NAME}

## Module Template
\`\`\`
// TODO: Your standard module/class template
\`\`\`

## Runtime Constraints
TODO: Language version restrictions, prohibited APIs, required wrappers.

## Common Patterns
TODO: Patterns agents should follow when writing code for this project."

write_if_new "${BASE_DIR}/context/skills/dev_testing/testing_patterns.md" "---
type: skill
scope: project-specific
version: \"1.0.0\"
domain: dev_testing
agents: [dev_testing]
---

# Dev Testing Skills — ${PROJECT_NAME}

## Test Framework
- **Framework**: TODO (e.g., Jest, Mocha, pytest)
- **Assertion**: TODO (e.g., Chai expect, Jest expect)
- **Mocking**: TODO (e.g., Sinon, Jest mocks, unittest.mock)

## Test File Location
TODO: Where do test files go? (e.g., \`test/\`, \`__tests__/\`, co-located)

## Test Naming
TODO: How are test files and test cases named?

## Mocking Patterns
\`\`\`
// TODO: Show your mocking pattern
\`\`\`

## Coverage Thresholds
- Lines: TODO%
- Branches: TODO%
- Functions: TODO%"

write_if_new "${BASE_DIR}/context/skills/reviewer/review_checklist.md" "---
type: skill
scope: project-specific
version: \"1.0.0\"
domain: reviewer
agents: [reviewer]
---

# Reviewer Skills — ${PROJECT_NAME}

## Review Dimensions
TODO: Define the dimensions to review against.

| Dimension | What to Check | Severity if Violated |
|-----------|--------------|---------------------|
| Security | TODO | critical |
| Performance | TODO | major |
| Code Quality | TODO | major |
| Testing | TODO | major |
| Style | TODO | minor |

## Severity Levels
- **P0 / critical**: Must fix before merge. Blocks pipeline.
- **P1 / major**: Should fix before merge. Blocks pipeline.
- **P2 / minor**: Nice to fix. Does not block.
- **P3 / info**: Suggestion only."

write_if_new "${BASE_DIR}/context/skills/healer/healing_patterns.md" "---
type: skill
scope: project-specific
version: \"1.0.0\"
domain: healer
agents: [healer]
---

# Healer Skills — ${PROJECT_NAME}

## When Healing Is Required
TODO: Define project-specific signals that indicate context gaps.

## What Can Be Healed
| Target File Type | Location | Heal When |
|-----------------|----------|-----------|
| Knowledge files | context/knowledge/*.md | Agent lacked codebase facts |
| Rules files | context/rules/*.md | Reviewer flagged violations not covered by rules |
| Guidelines files | context/guidelines/*.md | Code patterns required manual feedback |
| Skill files | context/skills/<agent>/*.md | Agent repeatedly misunderstood patterns |

## Healing Boundaries
- NEVER modify agent instruction files (.github/agents/*.agent.md)
- ONLY modify context files, skill files, and pipeline config
- APPEND new knowledge rather than rewriting existing content
- PRESERVE existing rule IDs and severity levels

## Heal Report Template
\`\`\`markdown
# Heal Report — {{task_id}}

## Execution Analysis
- **Pipeline inline**: YES | NO
- **Rework cycles**: N
- **User interventions**: N
- **Stage failures**: N

## Deviations Detected
| # | Stage | Type | Description |

## Healing Actions
| # | Target File | Action | Rationale |

## Files Modified
| File | Change Type | Summary |

## Summary
\`\`\`"

write_if_new "${BASE_DIR}/context/skills/documenter/feature.template.md" "---
type: skill
scope: project-specific
version: \"1.0.0\"
domain: documenter
agents: [documenter]
template_type: feature
---

# {{title}}

## Summary
<!-- Brief description of the feature and its business value -->
{{summary}}

## Background
<!-- Context, motivation, and related tickets -->
{{background}}

## Requirements
### Functional Requirements
| ID | Description | Priority |
|----|-------------|----------|
{{fr_table}}

### Non-Functional Requirements
| ID | Description | Priority |
|----|-------------|----------|
{{nfr_table}}

## Technical Design
### Architecture
{{architecture_description}}

### Components Modified
| Component | Change Type | Description |
|-----------|------------|-------------|
{{component_table}}

### Design Decisions
| Decision | Option Chosen | Rationale |
|----------|--------------|-----------|
{{decisions_table}}

## Implementation
### Files Changed
| File | Action | Description |
|------|--------|-------------|
{{files_table}}

### Key Implementation Details
{{implementation_details}}

## Testing
### Test Summary
| Metric | Value |
|--------|-------|
| Tests Added | {{tests_added}} |
| Tests Passed | {{tests_passed}} |
| Coverage | {{coverage}} |

## Review
- **Verdict**: {{verdict}}
- **Findings**: {{findings_summary}}

## Timeline
{{timeline_from_state}}"

write_if_new "${BASE_DIR}/context/skills/documenter/bug.template.md" "---
type: skill
scope: project-specific
version: \"1.0.0\"
domain: documenter
agents: [documenter]
template_type: bug
---

# {{title}}

## Bug Description
{{bug_description}}

### Symptoms
{{symptoms}}

### Impact
- **Severity**: {{severity}}
- **Affected Users/Systems**: {{impact}}

### Environment
| Property | Value |
|----------|-------|
{{environment_table}}

## Root Cause Analysis
### Investigation
{{investigation_steps}}

### Root Cause
{{root_cause}}

### Affected Code
{{affected_code_paths}}

## Fix
### Strategy
{{fix_strategy}}

### Files Changed
| File | Action | Description |
|------|--------|-------------|
{{files_table}}

### Side Effects
{{side_effects}}

## Testing
### Regression Tests
{{regression_tests}}

### Test Results
| Metric | Value |
|--------|-------|
| Tests Added | {{tests_added}} |
| Tests Passed | {{tests_passed}} |

## Prevention
{{prevention_recommendations}}"

write_if_new "${BASE_DIR}/context/skills/git_ops/git_conventions.md" "---
type: skill
scope: project-specific
version: \"1.0.0\"
domain: git_ops
agents: [git_ops]
---

# Git Operations — ${PROJECT_NAME}

## Branch Naming
- **Format**: \`<TICKET_KEY>_<change_name>\`
- **Examples**:
  - \`PROJ-1234_add_user_auth\`
  - \`BUG-567_fix_login_redirect\`

## Commit Message Format
- **First line**: \`<TICKET_KEY>: <imperative mood summary>\` (max 72 chars)
- **Body**: bullet list of changes

## PR Description
Include: Summary, Changes (file list), Documentation link, Test results, Review verdict.

## Files to Exclude
- \`adlc_repo_orchestrator/workspace/**\`
- \`.env\`, \`*.key\`, \`*.pem\`
- \`node_modules/\`, \`__pycache__/\`, build artifacts"

# ---------------------------------------------------------------------------
# Pipeline Configuration
# ---------------------------------------------------------------------------

write_if_new "${BASE_DIR}/configs/pipeline.yaml" "# ============================================================================
# ADLC Pipeline Configuration — ${PROJECT_NAME}
# ============================================================================
# Single source of truth: stages, agent config, tools, feedback routing.
# ============================================================================

pipeline:
  name: \"${PROJECT_NAME}_pipeline\"
  version: \"1.0.0\"
  state_file: \"workspace/{{task_id}}/state.yaml\"

# ---------------------------------------------------------------------------
# Stage Definitions
# ---------------------------------------------------------------------------
# Stages execute in \`order\` sequence. Set \`enabled: false\` to skip a stage.
# To reorder, change the order values. To add a stage, append an entry.
# ---------------------------------------------------------------------------
stages:
  - id: \"planner\"
    agent: \"planner\"
    order: 1
    enabled: true
    description: \"Decomposes user intent into an actionable task plan\"
    inputs:
      - \"workspace/{{task_id}}/docs/user_request.md\"
    outputs:
      - \"workspace/{{task_id}}/docs/task_plan.md\"

  - id: \"requirement\"
    agent: \"requirement\"
    order: 2
    enabled: true
    description: \"Expands task plan into a formal requirements document\"
    inputs:
      - \"workspace/{{task_id}}/docs/task_plan.md\"
    outputs:
      - \"workspace/{{task_id}}/docs/requirements.md\"

  - id: \"designer\"
    agent: \"designer\"
    order: 3
    enabled: true
    description: \"Produces technical design and architecture from requirements\"
    inputs:
      - \"workspace/{{task_id}}/docs/requirements.md\"
    outputs:
      - \"workspace/{{task_id}}/docs/design.md\"

  - id: \"developer\"
    agent: \"developer\"
    order: 4
    enabled: true
    description: \"Implements code changes directly in the repository\"
    inputs:
      - \"workspace/{{task_id}}/docs/design.md\"
      - \"workspace/{{task_id}}/docs/requirements.md\"
    outputs:
      - \"workspace/{{task_id}}/artefacts/IMPLEMENTATION_NOTES.md\"

  - id: \"dev_testing\"
    agent: \"dev-testing\"
    order: 5
    enabled: true
    description: \"Writes and runs tests against implemented code\"
    inputs:
      - \"workspace/{{task_id}}/artefacts/IMPLEMENTATION_NOTES.md\"
      - \"workspace/{{task_id}}/docs/requirements.md\"
    outputs:
      - \"workspace/{{task_id}}/reports/test_report.md\"

  - id: \"reviewer\"
    agent: \"reviewer\"
    order: 6
    enabled: true
    description: \"Reviews repository changes for quality, security, and compliance\"
    inputs:
      - \"workspace/{{task_id}}/artefacts/IMPLEMENTATION_NOTES.md\"
      - \"workspace/{{task_id}}/reports/test_report.md\"
      - \"workspace/{{task_id}}/docs/requirements.md\"
    outputs:
      - \"workspace/{{task_id}}/reports/review_report.md\"

  - id: \"documenter\"
    agent: \"documenter\"
    order: 7
    enabled: true
    description: \"Generates technical document and publishes to Confluence\"
    inputs:
      - \"workspace/{{task_id}}/docs/user_request.md\"
      - \"workspace/{{task_id}}/docs/task_plan.md\"
      - \"workspace/{{task_id}}/docs/requirements.md\"
      - \"workspace/{{task_id}}/docs/design.md\"
      - \"workspace/{{task_id}}/artefacts/IMPLEMENTATION_NOTES.md\"
      - \"workspace/{{task_id}}/reports/test_report.md\"
      - \"workspace/{{task_id}}/reports/review_report.md\"
    outputs:
      - \"workspace/{{task_id}}/reports/techno_doc.md\"

  - id: \"healer\"
    agent: \"healer\"
    order: 8
    enabled: true
    description: \"Retrospects pipeline execution and heals context files to prevent recurrence\"
    inputs:
      - \"workspace/{{task_id}}/state.yaml\"
      - \"workspace/{{task_id}}/feedbacks/\"
      - \"workspace/{{task_id}}/reports/review_report.md\"
      - \"workspace/{{task_id}}/reports/test_report.md\"
      - \"workspace/{{task_id}}/docs/user_request.md\"
      - \"workspace/{{task_id}}/artefacts/IMPLEMENTATION_NOTES.md\"
      - \"workspace/{{task_id}}/docs/requirements.md\"
    outputs:
      - \"workspace/{{task_id}}/reports/heal_report.md\"

  - id: \"git_ops\"
    agent: \"git-ops\"
    order: 9
    enabled: true
    description: \"Creates branch, commits, pushes, and raises PR\"
    inputs:
      - \"workspace/{{task_id}}/docs/user_request.md\"
      - \"workspace/{{task_id}}/docs/task_plan.md\"
      - \"workspace/{{task_id}}/artefacts/IMPLEMENTATION_NOTES.md\"
      - \"workspace/{{task_id}}/reports/techno_doc.md\"
      - \"workspace/{{task_id}}/reports/review_report.md\"
      - \"workspace/{{task_id}}/reports/heal_report.md\"
    outputs:
      - \"workspace/{{task_id}}/reports/pr_report.md\"

# ---------------------------------------------------------------------------
# Context Injection Paths
# ---------------------------------------------------------------------------
context:
  skills_dir: \"context/skills/\"
  rules_dir: \"context/rules/\"
  knowledge_dir: \"context/knowledge/\"
  guidelines_dir: \"context/guidelines/\"

# ---------------------------------------------------------------------------
# Agent Defaults
# ---------------------------------------------------------------------------
agent_defaults:
  model: \"claude-sonnet-4-20250514\"
  temperature: 0.2
  max_iterations: 3
  confidence_threshold: 0.8          # 0.0\u20131.0, minimum confidence to proceed
  tools:
    - \"read_file\"
    - \"create_file\"
    - \"replace_string_in_file\"
    - \"grep_search\"
    - \"file_search\"
    - \"semantic_search\"
    - \"run_in_terminal\"
    - \"list_dir\"
    - \"runTests\"

# ---------------------------------------------------------------------------
# Per-Agent Overrides
# ---------------------------------------------------------------------------
# Customize tools, model, temperature per stage. Only override what differs.
# ---------------------------------------------------------------------------
agent_overrides:
  planner:
    temperature: 0.4
    tools:
      - \"read_file\"
      - \"create_file\"
      - \"semantic_search\"
      - \"list_dir\"
      - \"file_search\"
      # - \"com.atlassian/atlassian-mcp-server/*\"  # Uncomment if you have Jira MCP

  developer:
    temperature: 0.1
    max_iterations: 5
    repo_write_access: true
    tools:
      - \"read_file\"
      - \"create_file\"
      - \"replace_string_in_file\"
      - \"multi_replace_string_in_file\"
      - \"grep_search\"
      - \"file_search\"
      - \"semantic_search\"
      - \"run_in_terminal\"
      - \"list_dir\"
      - \"runTests\"
      - \"get_errors\"

  dev_testing:
    temperature: 0.1
    max_iterations: 5
    tools:
      - \"read_file\"
      - \"create_file\"
      - \"replace_string_in_file\"
      - \"grep_search\"
      - \"file_search\"
      - \"run_in_terminal\"
      - \"runTests\"
      - \"get_errors\"

  reviewer:
    temperature: 0.3
    tools:
      - \"read_file\"
      - \"create_file\"
      - \"grep_search\"
      - \"file_search\"
      - \"semantic_search\"
      - \"list_dir\"
      - \"get_errors\"

  documenter:
    temperature: 0.3
    tools:
      - \"read_file\"
      - \"create_file\"
      - \"replace_string_in_file\"
      - \"list_dir\"
      - \"file_search\"
      - \"grep_search\"
      # - \"com.atlassian/atlassian-mcp-server/*\"  # Uncomment if you have Confluence MCP

  healer:
    temperature: 0.2
    max_iterations: 3
    tools:
      - \"read_file\"
      - \"create_file\"
      - \"replace_string_in_file\"
      - \"grep_search\"
      - \"file_search\"
      - \"semantic_search\"
      - \"list_dir\"

  git_ops:
    temperature: 0.1
    tools:
      - \"read_file\"
      - \"create_file\"
      - \"replace_string_in_file\"
      - \"grep_search\"
      - \"file_search\"
      - \"run_in_terminal\"
      - \"list_dir\"

# ---------------------------------------------------------------------------
# Feedback & Routing
# ---------------------------------------------------------------------------
feedback:
  directory: \"workspace/{{task_id}}/feedbacks/\"
  max_rework_cycles: 3
  routing_map:
    reviewer_to_developer: \"reviewer -> developer\"
    reviewer_to_designer: \"reviewer -> designer\"
    dev_testing_to_developer: \"dev_testing -> developer\"
    requirement_to_planner: \"requirement -> planner\"
    designer_to_requirement: \"designer -> requirement\"

# ---------------------------------------------------------------------------
# Documentation Publishing (optional — remove if not using Confluence)
# ---------------------------------------------------------------------------
documentation:
  platform: \"confluence\"
  space_key: \"\"              # TODO: Set your Confluence space key
  parent_page_id: \"\"         # TODO: Set the parent page ID
  title_prefix: \"ADLC\"

# ---------------------------------------------------------------------------
# Git Operations (optional — remove if not using git-ops stage)
# ---------------------------------------------------------------------------
git_ops:
  base_branch: \"\"            # Empty = use current branch
  auto_push: true
  auto_pr: true

# ---------------------------------------------------------------------------
# Confidence Gating
# ---------------------------------------------------------------------------
confidence:
  max_retries: 2                       # Re-invocations to improve confidence before escalation
  on_low_confidence: \"ask_user\"        # ask_user | proceed_with_warning | fail

# ---------------------------------------------------------------------------
# Workspace Conventions
# ---------------------------------------------------------------------------
workspace:
  task_prefix: \"task-\"
  directories:
    - \"docs\"
    - \"artefacts\"
    - \"feedbacks\"
    - \"reports\""

# ---------------------------------------------------------------------------
# Workspace .gitkeep
# ---------------------------------------------------------------------------
write_if_new "${BASE_DIR}/workspace/.gitkeep" ""

# ---------------------------------------------------------------------------
# .gitignore entry
# ---------------------------------------------------------------------------
GITIGNORE_ENTRY="adlc_repo_orchestrator/workspace/"

if [[ -f ".gitignore" ]]; then
  if ! grep -qF "${GITIGNORE_ENTRY}" .gitignore; then
    echo "" >> .gitignore
    echo "# ADLC Pipeline workspace (auto-generated, per-task)" >> .gitignore
    echo "${GITIGNORE_ENTRY}" >> .gitignore
    ok "Appended workspace/ to .gitignore"
  else
    ok ".gitignore already contains workspace entry"
  fi
else
  echo "# ADLC Pipeline workspace (auto-generated, per-task)" > .gitignore
  echo "${GITIGNORE_ENTRY}" >> .gitignore
  ok "Created .gitignore with workspace entry"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=============================================="
echo -e "${GREEN}ADLC Pipeline bootstrap complete!${NC}"
echo "=============================================="
echo ""
echo "Created structure:"
echo "  ${BASE_DIR}/"
echo "    ├── configs/pipeline.yaml"
echo "    ├── context/"
echo "    │   ├── rules/${PROJECT_NAME}_rules.md"
echo "    │   ├── knowledge/{architecture,modules,tech_stack}.md"
echo "    │   ├── guidelines/{coding_patterns,naming_conventions}.md"
echo "    │   └── skills/{planner,requirement,designer,developer,dev_testing,reviewer,healer,documenter,git_ops}/"
echo "    └── workspace/.gitkeep"
echo ""
echo "Next steps:"
echo "  1. Copy agent files from reference repo:"
echo "     cp -r <reference-repo>/.github/agents/ .github/agents/"
echo "  2. Fill in the TODO sections in all skeleton context files"
echo "  3. Customize pipeline.yaml (tools, integrations, model)"
echo "  4. Test: @repo_orchestrator Start task: <description>"
echo ""
echo "See PORTING_GUIDE.md for detailed instructions and schemas."
