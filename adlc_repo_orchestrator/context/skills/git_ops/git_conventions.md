---
type: skill
scope: project-specific
version: "1.0.0"
domain: git_ops
agents: [git_ops]
---

# Git Operations — zephyr-shgw

## Branch Naming
- **Format**: `<TICKET_KEY>_<change_name>`
- **Examples**:
  - `PROJ-1234_add_user_auth`
  - `BUG-567_fix_login_redirect`

## Commit Message Format
- **First line**: `<TICKET_KEY>: <imperative mood summary>` (max 72 chars)
- **Body**: bullet list of changes

## PR Description
Include: Summary, Changes (file list), Documentation link, Test results, Review verdict.

## Files to Exclude
- `adlc_repo_orchestrator/workspace/**`
- `.env`, `*.key`, `*.pem`
- `node_modules/`, `__pycache__/`, build artifacts
