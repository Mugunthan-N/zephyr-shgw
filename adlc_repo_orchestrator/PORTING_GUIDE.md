# ADLC Pipeline — Porting Guide

A step-by-step guide for teams adopting the AI-driven Development Lifecycle (ADLC) pipeline in their repositories. Covers folder structure, porting instructions, context file schemas, and customization protocols.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [What Gets Ported vs What Stays](#2-what-gets-ported-vs-what-stays)
3. [Folder Structure](#3-folder-structure)
4. [Step-by-Step Porting](#4-step-by-step-porting)
5. [Context File Schemas](#5-context-file-schemas)
   - [5.1 Rules Schema](#51-rules-schema)
   - [5.2 Knowledge Schema](#52-knowledge-schema)
   - [5.3 Guidelines Schema](#53-guidelines-schema)
   - [5.4 Skills Schema](#54-skills-schema)
6. [Pipeline Configuration](#6-pipeline-configuration)
7. [Customization Protocols](#7-customization-protocols)
8. [Bootstrap Script](#8-bootstrap-script)
9. [Validation Checklist](#9-validation-checklist)
10. [FAQ](#10-faq)

---

## 1. Architecture Overview

The ADLC pipeline has three layers:

```
┌─────────────────────────────────────────────────────────────────────┐
│  AGENTS (generic, repo-agnostic)                                    │
│  .github/agents/*.agent.md                                          │
│  Contains instructions for each pipeline stage                      │
│  ✅ Copy as-is — no modification needed                             │
├─────────────────────────────────────────────────────────────────────┤
│  CONFIG (pipeline behavior)                                         │
│  adlc_repo_orchestrator/configs/pipeline.yaml                       │
│  Defines stages, order, tools, feedback, integrations               │
│  ⚙️  Modify for your project (tools, models, integrations)          │
├─────────────────────────────────────────────────────────────────────┤
│  CONTEXT (repo-specific knowledge)                                  │
│  adlc_repo_orchestrator/context/{rules,knowledge,guidelines,skills} │
│  Contains YOUR project's rules, patterns, architecture, templates   │
│  ✍️  Write from scratch for your project                            │
└─────────────────────────────────────────────────────────────────────┘
```

**Key principle**: Agents are the engine; context is the fuel. The same agents work across any repository — they become project-aware by reading the context directory at runtime.

---

## 2. What Gets Ported vs What Stays

| Component | Action | Reason |
|-----------|--------|--------|
| `.github/agents/*.agent.md` | **Copy as-is** | Generic instructions, no project specifics |
| `configs/pipeline.yaml` | **Copy + customize** | Adjust tools, models, integrations, stage order |
| `context/skills/documenter/*.template.md` | **Copy as-is** | Repo-agnostic document templates (feature/bug) |
| `context/skills/healer/healing_patterns.md` | **Copy as-is** | Repo-agnostic healing patterns and report template |
| `PORTING_GUIDE.md` | **Copy as-is** | Reference documentation for porting teams |
| `README.md` | **Copy as-is** | Pipeline overview and usage guide |
| `adlc_bootstrap.sh` | **Copy as-is** | Scaffolding script for skeleton context files |
| `context/rules/<project>_rules.md` | **Write new** | Your project's mandatory constraints |
| `context/knowledge/` | **Write new** | Your architecture, modules, tech stack, discoveries |
| `context/guidelines/` | **Write new** | Your coding patterns and naming conventions |
| `context/skills/<agent>/` | **Write new** | Your project-specific agent skills (per stage) |
| `workspace/` | **Ignore** | Auto-created at runtime, add to `.gitignore` |

---

## 3. Folder Structure

The complete structure to create in your repository:

```
<your-repo>/
├── .github/
│   └── agents/                           ← Agent instruction files
│       ├── repo_orchestrator.agent.md    ← Main orchestrator (user-invocable)
│       ├── planner.agent.md              ← Stage 1
│       ├── requirement.agent.md          ← Stage 2
│       ├── designer.agent.md             ← Stage 3
│       ├── developer.agent.md            ← Stage 4
│       ├── dev-testing.agent.md          ← Stage 5
│       ├── reviewer.agent.md             ← Stage 6
│       ├── documenter.agent.md           ← Stage 7
│       ├── healer.agent.md               ← Stage 8
│       └── git-ops.agent.md              ← Stage 9
│
├── adlc_repo_orchestrator/
│   ├── configs/
│   │   └── pipeline.yaml                 ← Single source of truth
│   │
│   ├── context/                          ← YOUR project knowledge (write this)
│   │   ├── rules/                        ← Mandatory coding rules
│   │   │   └── <project>_rules.md        ← Project-specific rules
│   │   │
│   │   ├── knowledge/                    ← Codebase facts and architecture
│   │   │   ├── architecture.md           ← System overview, layers, boot sequence
│   │   │   ├── modules.md                ← Directory map, key files, dependencies
│   │   │   ├── tech_stack.md             ← Runtime, frameworks, dependencies
│   │   │   └── events_and_communication.md ← Events, IPC, messaging (if applicable)
│   │   │
│   │   ├── guidelines/                   ← Coding style and pattern conventions
│   │   │   ├── coding_patterns.md        ← Patterns used in your codebase
│   │   │   └── naming_conventions.md     ← Naming rules for vars, files, events
│   │   │
│   │   └── skills/                       ← Agent-specific project knowledge
│   │       ├── planner/                  ← Task decomposition patterns
│   │       ├── requirement/              ← Requirements templates, NFR patterns
│   │       ├── designer/                 ← Design patterns, architecture decisions
│   │       ├── developer/                ← Code templates, runtime constraints
│   │       ├── dev_testing/              ← Test framework patterns, mocking
│   │       ├── reviewer/                 ← Review checklists, severity definitions
│   │       ├── healer/                   ← Healing patterns and report template
│   │       ├── documenter/               ← Document templates (bug/feature)
│   │       └── git_ops/                  ← Branch naming, commit conventions
│   │
│   └── workspace/                        ← Auto-created at runtime (gitignored)
│       └── .gitkeep
│
└── .gitignore                            ← Add: adlc_repo_orchestrator/workspace/
```

---

## 4. Step-by-Step Porting

### Step 1: Copy Pipeline Files from Reference Repository

Copy the entire pipeline structure from the reference repository into your repo:

```bash
# From your repository root
cp -r <reference-repo>/.github/agents/ .github/agents/
cp -r <reference-repo>/adlc_repo_orchestrator/ adlc_repo_orchestrator/
```

This copies:
- All 9 agent instruction files (`.github/agents/*.agent.md`)
- Pipeline configuration (`configs/pipeline.yaml`)
- Document templates (`context/skills/documenter/*.template.md`)
- Bootstrap script, porting guide, and README
- Empty context directories ready for your project content

### Step 1 (Alternative): Run the Bootstrap Script

If you don't have access to the reference repository, use the bootstrap script to scaffold the structure:

```bash
bash adlc_bootstrap.sh <your_project_name>
```

This creates the directory tree with skeleton context files. You will still need the agent files (`.github/agents/`) from the reference repository.

### Step 2: Customize `pipeline.yaml`

Open `configs/pipeline.yaml` and adjust:

1. **Tools** — Remove tools you don't need and add your own MCP servers:
   ```yaml
   agent_defaults:
     tools:
       - "read_file"
       - "create_file"
       # Add your own MCP server tool patterns here
   ```

2. **Stage order** — Reorder, enable, or disable stages:
   ```yaml
   stages:
     - id: "documenter"
       enabled: false    # Skip if you don't use Confluence
   ```

3. **Integrations** — Update Confluence, Git config:
   ```yaml
   documentation:
     space_key: "YOUR_SPACE"
     parent_page_id: "YOUR_PAGE_ID"
   ```

4. **Model** — Change the default model if needed:
   ```yaml
   agent_defaults:
     model: "claude-sonnet-4-20250514"   # Or your preferred model
   ```

### Step 3: Write Your Project Context

This is the main work. Follow the schemas in [Section 5](#5-context-file-schemas) to create each file. Start with:

1. **`knowledge/architecture.md`** — System overview (most impactful)
2. **`knowledge/modules.md`** — Directory map
3. **`knowledge/tech_stack.md`** — Runtime and dependencies
4. **`rules/<project>_rules.md`** — Your mandatory constraints
5. **`guidelines/coding_patterns.md`** — Patterns your team uses
6. **`guidelines/naming_conventions.md`** — Naming standards
7. **Skills files** — One per agent (can be added incrementally)

### Step 4: Update `.gitignore`

```gitignore
# ADLC Pipeline workspace (auto-generated, per-task)
adlc_repo_orchestrator/workspace/
```

### Step 5: Validate

Run through the [Validation Checklist](#9-validation-checklist) to ensure everything is set up correctly.

---

## 5. Context File Schemas

Every context file uses **YAML frontmatter** for machine-parseable metadata followed by **Markdown body** for agent-consumable content. This dual format ensures agents can both programmatically filter files and read rich instructions.

### General File Protocol

```markdown
---
type: <rule | knowledge | guideline | skill>
scope: <base | project-specific>
version: "1.0.0"
domain: <category within the type>
agents: [all] | [planner, developer, ...]   # Which agents consume this
---

# Human-Readable Title

Body content in Markdown...
```

**Frontmatter rules**:
- `type` — one of: `rule`, `knowledge`, `guideline`, `skill` (required)
- `scope` — `base` for repo-agnostic, anything else for project-specific (required)
- `version` — semver string, increment when content changes significantly (required)
- `domain` — categorization within the type (required)
- `agents` — list of agent stage IDs that should consume this file, or `[all]` (optional, defaults to `[all]`)

---

### 5.1 Rules Schema

Rules are **mandatory constraints**. Violations at `critical` or `major` severity block the pipeline (the reviewer will issue a FAIL verdict). Rules are the highest-authority context — they override guidelines when conflicts arise.

#### File Naming

```
context/rules/
├── <project>_rules.md          ← Project-specific rules
├── security_rules.md           ← Optional: split by category if > 150 rules
└── performance_rules.md        ← Optional: split by category
```

- Use `lower_snake_case.md`
- One file per category if the project has many rules
- There are no repo-agnostic base rules — all rules are project-specific

#### Rule Entry Schema

Each rule follows this structure inside the markdown body:

```markdown
---
type: rule
scope: <base | project-specific>
version: "1.0.0"
domain: <code-quality | error-handling | security | performance | testing | platform>
agents: [all]
---

# <Title> Rules

## <Category Name>

### R-<PREFIX>-<NNN>: <Rule Name>

- **Severity**: critical | major | minor
- **Description**: What the rule mandates and why.
- **Bad**:
  ```<lang>
  // What NOT to do
  ```
- **Good**:
  ```<lang>
  // What TO do
  ```
```

#### Field Reference

| Field | Required | Description |
|-------|----------|-------------|
| ID | Yes | Format: `R-<PREFIX>-<NNN>`. Prefix by category (CQ=code quality, EH=error handling, SC=security, PF=performance, TS=testing, EM=embedded, HW=hardware). Monotonically increasing number. |
| Severity | Yes | `critical` — blocks pipeline, must fix. `major` — blocks pipeline, should fix. `minor` — flagged as warning, does not block. |
| Description | Yes | Clear, actionable constraint. State what is required, not just what is forbidden. |
| Bad | Recommended | Code example showing the violation. |
| Good | Recommended | Code example showing the correct approach. |

#### Severity Impact

| Severity | Reviewer Action | Pipeline Impact |
|----------|----------------|-----------------|
| `critical` | FAIL verdict mandatory | Rework required |
| `major` | FAIL unless documented exception | Rework usually required |
| `minor` | WARNING in report, no FAIL | Informational |

#### Example: Project-Specific Rules File

```markdown
---
type: rule
scope: project-specific
version: "1.0.0"
domain: platform
agents: [all]
---

# Acme API — Project Rules

## API Design Rules

### R-API-001: Validate All Request Bodies

- **Severity**: critical
- **Description**: Every API endpoint accepting a request body MUST validate it against a JSON schema before processing. Use the shared `validateBody(schema, req)` middleware. Never trust client input.
- **Bad**:
  ```javascript
  app.post('/users', (req, res) => {
    db.insert(req.body);  // No validation
  });
  ```
- **Good**:
  ```javascript
  app.post('/users', validateBody(userSchema), (req, res) => {
    db.insert(req.validated);
  });
  ```

### R-API-002: Rate Limit All Public Endpoints

- **Severity**: major
- **Description**: All public-facing endpoints MUST have rate limiting configured. Use the `rateLimit()` middleware with per-IP limits.
```

---

### 5.2 Knowledge Schema

Knowledge files are **factual descriptions** of your codebase. They don't prescribe behavior — they inform agents about what exists, how it's structured, and how components interact. Agents use knowledge to make architecturally-aware decisions.

#### File Naming

```
context/knowledge/
├── architecture.md               ← System overview, layers, boot/startup sequence
├── modules.md                    ← Directory map, key files, module inventory
├── tech_stack.md                 ← Runtime, frameworks, dependencies, versions
├── events_and_communication.md   ← Events, IPC, messaging, pub/sub (if applicable)
├── data_models.md                ← Database schemas, API contracts (if applicable)
├── infrastructure.md             ← Deployment, CI/CD, environments (if applicable)
└── <domain>_map.md               ← Deep-dive into a specific subsystem (optional)
```

- Use `lower_snake_case.md`
- Start with the 3 core files: `architecture.md`, `modules.md`, `tech_stack.md`
- Add domain-specific files as needed
- **Maps** (e.g., `auth_map.md`, `database_map.md`) are deep-dives into subsystems — each links to related discoveries/details

#### Knowledge Entry Schema

```markdown
---
type: knowledge
scope: project-specific
version: "1.0.0"
domain: <architecture | modules | tech-stack | events | data-models | infrastructure | <subsystem>>
agents: [all]
---

# <Title>

## Overview
Brief description of what this file covers and why it matters.

## <Section>
Content organized by topic. Use:
- **Diagrams** (ASCII art or mermaid) for architecture and data flow
- **Tables** for inventories, dependency lists, configuration maps
- **Code blocks** for configuration examples, API signatures
- **Lists** for enumerations (directories, events, dependencies)
```

#### Core Knowledge Files — What to Include

**`architecture.md`** — required for all projects:
```markdown
## System Overview
What the system does, its primary purpose, deployment model.

## Startup / Boot Sequence
How the application initializes (entry point → config → services → ready).

## Layered Architecture
Diagram showing the layers/tiers and their responsibilities.
Which layer owns what concern?

## Key Design Decisions
Major architectural choices (monolith vs microservice, sync vs async, etc.)
and the reasons behind them.

## External Integrations
What external services/APIs the system connects to and how.
```

**`modules.md`** — required for all projects:
```markdown
## Directory Map
Top-level directory tree with one-line descriptions.

## Key Files
Critical files that agents should know about (entry points, config, shared utilities).

## Module Dependency Graph
How major modules depend on each other.
Which modules are foundational vs leaf-level?

## Configuration Files
Where configuration lives, format, environment variable mapping.
```

**`tech_stack.md`** — required for all projects:
```markdown
## Runtime
Language, version, runtime environment.

## Frameworks & Libraries
Major frameworks with versions and their role.

## Build Tools
Build system, bundler, task runner.

## Testing Stack
Test framework, assertion library, mocking library, coverage tool.

## CI/CD
Pipeline tool, key stages, deployment targets.

## Key Constraints
Version locks, compatibility requirements, deprecated features to avoid.
```

#### Discovery Files (Optional, Advanced)

For large codebases, individual discovery files capture specific implementation details, quirks, or gotchas:

```markdown
---
type: knowledge
scope: project-specific
version: "1.0.0"
domain: discovery
subsystem: <auth | database | api | ...>
tags: [quirk, constraint, pattern, gotcha, workaround]
---

# <Descriptive Title Stating the Discovery>

## Context
Where this applies (file, module, function).

## Detail
The specific implementation detail, constraint, or behavior.

## Why
Reason behind the behavior (if known).

## Impact
What happens if an agent ignores this.
```

Discovery files are linked from their parent **map** file (e.g., `auth_map.md` links to all auth-related discoveries).

---

### 5.3 Guidelines Schema

Guidelines are **style and pattern conventions**. They describe how your team writes code — not mandatory rules, but strong preferences. Agents treat guideline violations as minor findings (flagged but not blocking).

#### File Naming

```
context/guidelines/
├── coding_patterns.md           ← Code structure patterns, error handling conventions
├── naming_conventions.md        ← Variable, file, event naming rules
├── import_ordering.md           ← Import/require ordering (if applicable)
├── api_conventions.md           ← API design patterns (if applicable)
└── <topic>_conventions.md       ← Additional topic-specific conventions
```

#### Guideline Entry Schema

```markdown
---
type: guideline
scope: project-specific
version: "1.0.0"
domain: <coding-patterns | naming | imports | api | testing-style | ...>
agents: [all]
---

# <Title> Conventions

## <Pattern Name>

**When**: When to apply this pattern.
**Pattern**:
```<lang>
// The preferred way to write this
```
**Rationale**: Why this pattern is preferred.
**Avoid**:
```<lang>
// What to avoid
```
```

#### Coding Patterns — What to Document

Focus on patterns that **already exist** in your codebase. Agents need to match existing style, not invent new patterns.

| Category | What to Capture |
|----------|----------------|
| **Module structure** | How files/classes are organized (class + prototype methods? pure functions? factory pattern?) |
| **Error handling** | try/catch conventions, error propagation, logging format |
| **Async patterns** | Callbacks vs promises vs async/await? Which is used where? |
| **State management** | How state is stored and updated (FSMs, Redux, plain objects?) |
| **Configuration** | How config is loaded, validated, and accessed |
| **Logging** | Log format, levels, structured vs unstructured |
| **Event patterns** | Event naming, emission patterns, listener lifecycle |
| **Import ordering** | Standard lib → external → internal? Alphabetical? |

#### Naming Conventions — What to Document

| Category | Example |
|----------|---------|
| Variables / Functions | `camelCase`, `snake_case`, `PascalCase` |
| Constants | `UPPER_SNAKE_CASE` |
| Classes / Types | `PascalCase` |
| Files / Directories | `camelCase.js`, `kebab-case.ts`, `PascalCase.tsx` |
| Events | `lower_snake_case`, `camelCase`, `SCREAMING_SNAKE` |
| API fields | `snake_case`, `camelCase` |
| Database columns | `snake_case` |
| Environment variables | `UPPER_SNAKE_CASE` |
| Boolean variables | Prefix: `is`, `has`, `can`, `should` |

---

### 5.4 Skills Schema

Skills are **agent-specific procedural knowledge**. Each agent gets its own skills subdirectory. Skills tell agents HOW to do their job in the context of YOUR project — templates, checklists, tool triggers, and domain-specific procedures.

#### File Naming

```
context/skills/
├── planner/
│   └── decomposition_patterns.md     ← How to break down tasks in your project
├── requirement/
│   └── requirement_templates.md      ← NFR templates, acceptance criteria patterns
├── designer/
│   └── design_patterns.md            ← Architecture patterns, module templates
├── developer/
│   └── code_patterns.md              ← Code templates, runtime constraints
├── dev_testing/
│   └── testing_patterns.md           ← Test framework usage, mocking strategies
├── reviewer/
│   └── review_checklist.md           ← Review dimensions, severity definitions
├── healer/
│   └── healing_patterns.md           ← Healing patterns, deviation classification, report template
├── documenter/
│   ├── feature.template.md           ← Feature tech doc template
│   └── bug.template.md               ← Bug fix tech doc template
└── git_ops/
    └── git_conventions.md            ← Branch naming, commit format, PR template
```

- Directory name must match the stage `id` in `pipeline.yaml`
- Use `lower_snake_case.md` for files
- Each agent can have multiple skill files — split by concern

#### Skill Entry Schema

```markdown
---
type: skill
scope: project-specific
version: "1.0.0"
domain: <agent-stage-id>
agents: [<agent-stage-id>]
---

# <Agent Name> Skills — <Project Name>

## <Skill Topic>

### When to Apply
Condition or trigger for this skill.

### Procedure
Step-by-step instructions or template.

### Template
```<lang>
// Code template with placeholders
```

### Verification
How to verify the output is correct.
```

#### Per-Agent Skill Guidance

| Agent | Skill Files Should Cover |
|-------|------------------------|
| **planner** | How to decompose tasks in your project. Which areas require subtasks (API layer, DB, frontend, tests)? Component boundaries. Scope heuristics. Tool triggers (when to check Jira, search docs). |
| **requirement** | NFR templates (latency, uptime, security, scalability). Acceptance criteria patterns. Feature-type templates (API feature vs UI feature vs infrastructure). |
| **designer** | Module structure patterns. Where new files go. Inheritance hierarchies. Data model patterns. Integration patterns. Architecture decision templates. |
| **developer** | Code templates (module, class, handler, middleware). Runtime constraints (language version, prohibited APIs). Wrapper usage (custom FS, custom logger, etc). Platform idioms. |
| **dev_testing** | Test framework details (Jest/Mocha/pytest/etc). Mocking patterns (how to mock DB, API, filesystem). Coverage thresholds. Test file naming and location. Assertion patterns. |
| **reviewer** | Review dimensions (security, performance, style, correctness). Severity definitions (P0-P4 or critical/major/minor). Verification methods per dimension. Example review output. |
| **documenter** | Document templates are structured differently — see below. |
| **git_ops** | Branch naming rules. Commit message format. PR description template. Files to exclude from commits. Pre/post-flight checks. |

#### Document Templates (Documenter Skills)

The documenter agent uses structured templates with placeholder markers. Two templates are standard:

**`feature.template.md`** structure:
```markdown
---
type: skill
scope: project-specific
version: "1.0.0"
domain: documenter
agents: [documenter]
template_type: feature
---

# {{title}}

## Summary
<!-- Brief description of the feature -->
{{summary}}

## Requirements
| ID | Description | Type | Priority |
|----|-------------|------|----------|
{{requirements_table}}

## Technical Design
### Architecture
{{architecture_description}}

### Components
{{component_breakdown}}

## Implementation
### Files Changed
{{files_table}}

## Testing
### Results
{{test_results}}

## Review
{{review_verdict}}
```

**`bug.template.md`** structure:
```markdown
---
type: skill
scope: project-specific
version: "1.0.0"
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
{{impact}}

## Root Cause Analysis
{{root_cause}}

## Fix
### Strategy
{{fix_strategy}}

### Files Changed
{{files_table}}

## Testing
### Regression Tests
{{regression_tests}}

## Prevention
{{prevention_recommendations}}
```

#### Tool Usage Section (Optional)

If your project uses MCP servers or specific tools, add a "Configured Tool Usage" section to the relevant skill file:

```markdown
## Configured Tool Usage

### <Tool Name> (`<tool_pattern>`)
- **When**: <Trigger condition — when should the agent use this tool>
- **How**: <Brief usage pattern or example invocation>
- **Fallback**: <What to do if the tool is unavailable>
```

---

## 6. Pipeline Configuration

### `pipeline.yaml` — Field Reference

```yaml
pipeline:
  name: "<your-pipeline-name>"        # Identifier for this pipeline
  version: "1.0.0"                     # Config version
  state_file: "workspace/{{task_id}}/state.yaml"

stages:
  - id: "<unique_stage_id>"           # Used in state, feedback routing, skill lookup
    agent: "<agent-name>"              # Must match .github/agents/<agent-name>.agent.md
    order: <integer>                   # Execution order (sorted ascending, gaps allowed)
    enabled: true                      # Set false to skip
    description: "<what this stage does>"
    inputs:                            # Workspace files this stage reads
      - "workspace/{{task_id}}/docs/<file>.md"
    outputs:                           # Workspace files this stage must produce
      - "workspace/{{task_id}}/docs/<file>.md"

context:
  skills_dir: "context/skills/"
  rules_dir: "context/rules/"
  knowledge_dir: "context/knowledge/"
  guidelines_dir: "context/guidelines/"

agent_defaults:
  model: "<model-name>"               # Default LLM model
  temperature: 0.2                     # Default temperature
  max_iterations: 3                    # Default self-correction loops
  tools: [...]                         # Default tool list for all agents

agent_overrides:
  <stage_id>:                          # Override defaults for this stage
    model: "<model>"
    temperature: <float>
    max_iterations: <int>
    repo_write_access: true            # Only for developer stage
    tools: [...]

feedback:
  directory: "workspace/{{task_id}}/feedbacks/"
  max_rework_cycles: 3
  routing_map:                         # Which stages can send feedback to which
    <source>_to_<target>: "<source> -> <target>"

documentation:                         # Confluence integration (optional)
  platform: "confluence"
  space_key: "<SPACE_KEY>"
  parent_page_id: "<PAGE_ID>"
  title_prefix: "<PREFIX>"

git_ops:                               # Git integration (optional)
  base_branch: ""                      # Empty = use current branch
  auto_push: true
  auto_pr: true

workspace:
  task_prefix: "task-"
  directories: [docs, artefacts, feedbacks, reports]
```

### Customizing Tool Access

Each agent only has access to tools listed in its `agent_overrides.<stage>.tools` array (falling back to `agent_defaults.tools`). Common configurations:

| Agent | Typical Tools | Notes |
|-------|--------------|-------|
| planner | read, create, search, list_dir | Read-only + document creation |
| requirement | read, create, search | Read-only + document creation |
| designer | read, create, search, list_dir | Read-only + document creation |
| developer | read, create, replace, search, terminal, tests, errors | Full write access |
| dev_testing | read, create, replace, search, terminal, tests, errors | Full write access |
| reviewer | read, create, search, list_dir, errors | Read + report creation |
| documenter | read, create, replace, search | + Confluence MCP if available |
| git_ops | read, create, replace, search, terminal | Needs terminal for git commands |

### Adding MCP Server Tools

To make an MCP server available to a specific agent:

1. Add the tool pattern to `agent_overrides.<stage>.tools`:
   ```yaml
   agent_overrides:
     planner:
       tools:
         - "com.atlassian/atlassian-mcp-server/*"
   ```
2. Document when to use it in the agent's skill file:
   ```markdown
   ## Configured Tool Usage
   ### Atlassian MCP (`com.atlassian/atlassian-mcp-server/*`)
   - **When**: User provides a Jira ticket key — fetch ticket details
   ```

---

## 7. Customization Protocols

### Adding a New Stage

1. Create `.github/agents/<agent-name>.agent.md` following the standard agent template:
   ```markdown
   ---
   description: "<Agent description>"
   tools: [read, search, edit]
   user-invocable: false
   ---

   You are the **<Agent Name>** — stage N of the pipeline. <Purpose>.

   ## Step 0 — Load Config
   Read `adlc_repo_orchestrator/configs/pipeline.yaml` first.
   Extract config from `stages[<id>]` and `agent_overrides.<id>`.

   ## I/O Contract
   **Inputs**: <list workspace files>
   **Outputs**: <list workspace files>

   ## Execution
   <Step-by-step instructions>

   ## Boundaries
   <What this agent may and may not do>
   ```

2. Add to `pipeline.yaml`:
   ```yaml
   stages:
     - id: "my_stage"
       agent: "my-agent"
       order: 9
       enabled: true
       description: "Does something useful"
       inputs: [...]
       outputs: [...]
   ```

3. Add to orchestrator frontmatter:
   ```yaml
   agents: [..., my-agent]
   ```

4. Optionally create `context/skills/my_stage/` with skill files.

### Disabling a Stage

```yaml
- id: "documenter"
  enabled: false   # Stage is skipped
```

### Reordering Stages

Change `order` values. Gaps are fine:

```yaml
- id: "planner"
  order: 10
- id: "designer"
  order: 20    # Move designer before requirement
- id: "requirement"
  order: 30
```

### Adding Feedback Routes

Only add routes between stages that can meaningfully provide feedback:

```yaml
feedback:
  routing_map:
    # Format: <source>_to_<target>: "<source> -> <target>"
    my_stage_to_developer: "my_stage -> developer"
```

### Changing the Default Model

```yaml
agent_defaults:
  model: "gpt-4o"              # Global default

agent_overrides:
  developer:
    model: "claude-sonnet-4-20250514"  # Override for developer only
```

---

## 8. Bootstrap Script

A shell script to create the entire folder structure with skeleton files. See `adlc_bootstrap.sh` in the `adlc_repo_orchestrator/` directory.

Run it from your repository root:

```bash
bash adlc_repo_orchestrator/adlc_bootstrap.sh
```

Or for a fresh start (before copying from reference):

```bash
# Download and run
curl -sL <url-to-bootstrap-script> | bash
```

The script creates:
- All directories under `adlc_repo_orchestrator/`
- Skeleton context files with correct frontmatter and section headers
- A `.gitkeep` in `workspace/`
- Appends to `.gitignore`

---

## 9. Validation Checklist

After porting, verify each item:

### Structure
- [ ] `.github/agents/` contains all 9 agent files
- [ ] `adlc_repo_orchestrator/configs/pipeline.yaml` exists and is valid YAML
- [ ] `adlc_repo_orchestrator/context/rules/` has at least one `<project>_rules.md`
- [ ] `adlc_repo_orchestrator/context/knowledge/` has at least `architecture.md`, `modules.md`, `tech_stack.md`
- [ ] `adlc_repo_orchestrator/context/guidelines/` has at least one file
- [ ] `adlc_repo_orchestrator/context/skills/` has one subdirectory per enabled stage
- [ ] `adlc_repo_orchestrator/workspace/` is in `.gitignore`

### Configuration
- [ ] `pipeline.yaml` → `stages[]` lists all stages with unique IDs
- [ ] `pipeline.yaml` → `agent_overrides` has entries for stages needing custom tools
- [ ] `pipeline.yaml` → feedback routing map has valid stage references
- [ ] All `agent` values in stages match `.github/agents/<name>.agent.md` filenames
- [ ] Tools listed in overrides are actually available in your VS Code setup
- [ ] MCP server patterns match your installed MCP servers

### Context Quality
- [ ] All context files have valid YAML frontmatter
- [ ] Rules have unique IDs with consistent prefix format
- [ ] Knowledge files accurately describe your current architecture
- [ ] Guidelines match patterns actually used in the codebase
- [ ] Skill files reference correct framework/tools for your project
- [ ] Document templates (bug/feature) have all placeholder markers

### Smoke Test
- [ ] Open VS Code in the repository
- [ ] `@repo_orchestrator` appears in Copilot Chat agent dropdown
- [ ] Run: `@repo_orchestrator Status: task-000` → should report "no tasks found" or similar
- [ ] Run: `@repo_orchestrator Start task: <simple test description>` → pipeline starts

---

## 10. FAQ

**Q: Do I need to write ALL context files before starting?**
A: No. Start with `knowledge/architecture.md`, `knowledge/modules.md`, `knowledge/tech_stack.md`, and one `rules/<project>_rules.md`. The pipeline will work — agents will just have less project context. Add more files incrementally.

**Q: Can I add context files after the pipeline is running?**
A: Yes. Context files are loaded fresh at runtime before each stage. Add or modify files anytime.

**Q: What if I don't use Confluence?**
A: Set `documenter` stage to `enabled: false` in `pipeline.yaml`, or remove the `documentation` section. The documenter will still generate `techno_doc.md` locally but skip publishing.

**Q: What if I don't have the `gh` CLI for PR creation?**
A: The git-ops agent handles this gracefully — it logs the branch name and skips PR creation. You can also set `git_ops` stage to `enabled: false`.

**Q: How do I handle a monorepo with multiple projects?**
A: Create separate skill files per project/package and use the `agents` frontmatter field to target specific agents. Alternatively, run separate pipeline instances with different `pipeline.yaml` configs.

**Q: How big should context files be?**
A: Guidelines:
| Type | Max Lines | Action When Exceeded |
|------|-----------|---------------------|
| Rules | ~150 rules per file | Split by category |
| Knowledge | ~200 lines per file | Split by subsystem |
| Guidelines | ~200 lines per file | Split by topic |
| Skills | ~350 lines per file | Split by concern |

**Q: Can I use this with other editors (not VS Code)?**
A: The pipeline is designed for VS Code Copilot agents. The context files and pipeline config are editor-agnostic, but the agent files (`.agent.md`) and orchestration rely on VS Code Copilot's agent system.

**Q: How do rework loops work?**
A: When a downstream stage (e.g., reviewer) finds issues, it writes a feedback file to `feedbacks/`. The orchestrator routes the task back to the responsible upstream stage (e.g., developer) based on `feedback.routing_map`. The fix-review cycle repeats up to `max_rework_cycles` times.

**Q: What model should I use?**
A: Claude Sonnet 4 (`claude-sonnet-4-20250514`) is recommended for all stages. Use a higher-capability model for complex stages (developer, reviewer) if budget allows.
