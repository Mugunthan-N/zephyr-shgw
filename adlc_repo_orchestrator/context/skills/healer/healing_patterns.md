---
type: skill
scope: project-specific
version: "1.0.0"
domain: healer
agents: [healer]
---

# Healer Skills — Healing Patterns

## When Healing Is Required

The healer agent activates when the pipeline execution deviated from the expected path. Deviations include:

1. **Rework cycles** — Feedback was generated between stages (reviewer → developer, dev_testing → developer, etc.)
2. **User interventions** — The user provided mid-pipeline corrections or overrides that changed the task direction
3. **Stage failures** — A stage failed and was retried or adapted
4. **Context gaps** — An agent lacked project-specific knowledge and had to improvise

## What Can Be Healed

| Target File Type | Location | Heal When |
|-----------------|----------|-----------|
| Knowledge files | `context/knowledge/*.md` | Agent lacked codebase facts (architecture, modules, tech stack) |
| Rules files | `context/rules/*.md` | Reviewer flagged violations not covered by existing rules |
| Guidelines files | `context/guidelines/*.md` | Code patterns or naming issues required manual feedback |
| Skill files | `context/skills/<agent>/*.md` | An agent repeatedly misunderstood project-specific patterns |
| Pipeline config | `configs/pipeline.yaml` | Stage ordering, tool config, or feedback routing needed adjustment |

## Healing Boundaries

- **NEVER** modify agent instruction files (`.github/agents/*.agent.md`) — those are generic and repo-agnostic
- **ONLY** modify context files, skill files, and pipeline config
- **Append** new knowledge rather than rewriting existing content
- **Preserve** existing rule IDs and severity levels — only add new rules
- **Use frontmatter** `healed_by` and `healed_at` annotations when modifying files

## Healing Strategies

### Strategy 1: Knowledge Gap Filling
When feedback or rework was caused by missing codebase knowledge:
- Identify what fact was missing
- Add it to the appropriate `knowledge/` file
- Use the format established in existing knowledge files

### Strategy 2: Rule Codification
When a reviewer finding revealed an unwritten rule:
- Extract the rule from the feedback/review report
- Assign a new rule ID following the existing numbering scheme
- Add to the appropriate `rules/` file with severity, description, and examples

### Strategy 3: Guideline Extraction
When code style or pattern feedback was given:
- Extract the pattern from feedback
- Add to the appropriate `guidelines/` file

### Strategy 4: Skill Enhancement
When an agent repeatedly needed correction for the same type of task:
- Identify the pattern the agent should have known
- Add it to `context/skills/<agent>/`
- Include concrete examples from the current pipeline run

## Heal Report Template

The heal report should follow this structure:
```markdown
# Heal Report — {{task_id}}

## Execution Analysis
- **Pipeline inline**: YES | NO
- **Rework cycles**: N
- **User interventions**: N
- **Stage failures**: N

## Deviations Detected
| # | Stage | Type | Description |
|---|-------|------|-------------|

## Healing Actions
| # | Target File | Action | Rationale |
|---|-------------|--------|-----------|

## Files Modified
| File | Change Type | Lines Changed |
|------|-------------|---------------|

## Summary
<Brief narrative of what was healed and why>
```
