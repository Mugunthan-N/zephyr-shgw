#!/usr/bin/env bash
# =============================================================================
# ADLC Pipeline — Port Script
# =============================================================================
# Ports the ADLC pipeline from the reference repository into the current repo.
# Run from your repository root:
#
#   Option 1 — One-liner (clone + port + cleanup):
#
#     git clone --depth 1 -b ADLC_pilot_branch git@github.com:rently-com/Rently_Awesome_Copilot.git /tmp/_adlc_ref \
#       && bash /tmp/_adlc_ref/adlc_repo_orchestrator/adlc_port.sh [project_name] \
#       && rm -rf /tmp/_adlc_ref
#
#   Option 2 — If you already have the reference repo cloned:
#
#     bash <path-to-ref>/adlc_repo_orchestrator/adlc_port.sh [project_name]
#
# What it does:
#   1. Uses a local reference repo or shallow-clones the ADLC reference branch
#   2. Copies all repo-agnostic pipeline files (agents, config, templates, docs)
#   3. Creates empty context directories for your project-specific content
#   4. Runs the bootstrap script to generate skeleton context files
#   5. Appends workspace/ to .gitignore
#
# Prerequisites:
#   - git (with access to rently-com/Rently_Awesome_Copilot)
#   - Run from a git repository root
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
REPO_URL="git@github.com:rently-com/Rently_Awesome_Copilot.git"
BRANCH="ADLC_pilot_branch"
BASE_DIR="adlc_repo_orchestrator"
AGENTS_DIR=".github/agents"
PROJECT_NAME="${1:-my_project}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
step()  { echo -e "${CYAN}[STEP]${NC}  $1"; }

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
if [[ ! -d ".git" ]]; then
  error "Not a git repository. Run this script from your repository root."
  exit 1
fi

if ! command -v git &>/dev/null; then
  error "'git' is required but not found in PATH."
  exit 1
fi

# Warn if pipeline already exists
if [[ -d "${BASE_DIR}/configs" ]] && [[ -f "${BASE_DIR}/configs/pipeline.yaml" ]]; then
  warn "ADLC pipeline already exists in this repository."
  warn "Existing files will NOT be overwritten. Only missing files will be added."
  echo ""
fi

echo ""
echo "=============================================="
echo -e "${CYAN}ADLC Pipeline — Porting Script${NC}"
echo "=============================================="
echo ""
info "Project name: ${PROJECT_NAME}"
info "Source: ${REPO_URL} @ ${BRANCH}"
echo ""

# ---------------------------------------------------------------------------
# Step 1: Determine source — local reference repo or remote clone
# ---------------------------------------------------------------------------
# If the script is run from inside a clone of the reference repo, re-use it
# directly instead of cloning again. This makes the one-liner work:
#   git clone ... /tmp/_adlc && bash /tmp/_adlc/.../adlc_port.sh hub && rm -rf /tmp/_adlc
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
CLEANUP_TEMP=false

if [[ -n "${SCRIPT_DIR}" ]] \
   && [[ -f "${SCRIPT_DIR}/configs/pipeline.yaml" ]] \
   && [[ -d "${SCRIPT_DIR}/../.github/agents" ]]; then
  # Running from inside the reference repo — use parent as source
  TEMP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
  step "1/5 — Using local reference repo: ${TEMP_DIR}"
  ok "Skipped remote clone (running from local checkout)"
else
  step "1/5 — Cloning ADLC reference branch (shallow via SSH)..."

  TEMP_DIR=$(mktemp -d)
  CLEANUP_TEMP=true
  trap 'rm -rf "${TEMP_DIR}"' EXIT

  if ! git clone --depth 1 --branch "${BRANCH}" --single-branch "${REPO_URL}" "${TEMP_DIR}" 2>/dev/null; then
    error "Failed to clone reference repository via SSH."
    error "Ensure SSH access to: ${REPO_URL}"
    error ""
    error "Troubleshooting:"
    error "  1. Verify SSH key: ssh -T git@github.com"
    error "  2. Clone manually and run the script from inside:"
    error "     git clone -b ${BRANCH} ${REPO_URL} /tmp/_adlc_ref"
    error "     bash /tmp/_adlc_ref/${BASE_DIR}/adlc_port.sh ${PROJECT_NAME}"
    error "     rm -rf /tmp/_adlc_ref"
    exit 1
  fi

  ok "Reference branch cloned"
fi

# ---------------------------------------------------------------------------
# Step 2: Copy repo-agnostic agent files
# ---------------------------------------------------------------------------
step "2/5 — Copying agent instruction files..."

COPIED=0
SKIPPED=0

copy_if_new() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "${dst}")"
  if [[ -f "${dst}" ]]; then
    warn "Skipped (exists): ${dst}"
    ((SKIPPED++)) || true
  else
    cp "${src}" "${dst}"
    ok "Copied: ${dst}"
    ((COPIED++)) || true
  fi
}

# Agent files (.github/agents/)
AGENT_FILES=(
  "designer.agent.md"
  "dev-testing.agent.md"
  "developer.agent.md"
  "documenter.agent.md"
  "git-ops.agent.md"
  "healer.agent.md"
  "planner.agent.md"
  "repo_orchestrator.agent.md"
  "requirement.agent.md"
  "reviewer.agent.md"
)

for agent_file in "${AGENT_FILES[@]}"; do
  if [[ -f "${TEMP_DIR}/${AGENTS_DIR}/${agent_file}" ]]; then
    copy_if_new "${TEMP_DIR}/${AGENTS_DIR}/${agent_file}" "${AGENTS_DIR}/${agent_file}"
  else
    warn "Agent file not found in reference: ${agent_file}"
  fi
done

ok "Agent files processed (${COPIED} copied, ${SKIPPED} skipped)"

# ---------------------------------------------------------------------------
# Step 3: Copy pipeline config, templates, and documentation
# ---------------------------------------------------------------------------
step "3/5 — Copying pipeline config, templates, and docs..."

COPIED=0
SKIPPED=0

# Pipeline configuration
copy_if_new "${TEMP_DIR}/${BASE_DIR}/configs/pipeline.yaml" \
            "${BASE_DIR}/configs/pipeline.yaml"

# Documenter templates (repo-agnostic)
copy_if_new "${TEMP_DIR}/${BASE_DIR}/context/skills/documenter/feature.template.md" \
            "${BASE_DIR}/context/skills/documenter/feature.template.md"

copy_if_new "${TEMP_DIR}/${BASE_DIR}/context/skills/documenter/bug.template.md" \
            "${BASE_DIR}/context/skills/documenter/bug.template.md"

# Healer skill templates (repo-agnostic)
copy_if_new "${TEMP_DIR}/${BASE_DIR}/context/skills/healer/healing_patterns.md" \
            "${BASE_DIR}/context/skills/healer/healing_patterns.md"

# Documentation and supporting scripts
copy_if_new "${TEMP_DIR}/PORTING_GUIDE.md" \
            "${BASE_DIR}/PORTING_GUIDE.md"

copy_if_new "${TEMP_DIR}/${BASE_DIR}/adlc_bootstrap.sh" \
            "${BASE_DIR}/adlc_bootstrap.sh"

# This script itself
copy_if_new "${TEMP_DIR}/${BASE_DIR}/adlc_port.sh" \
            "${BASE_DIR}/adlc_port.sh"

ok "Pipeline files processed (${COPIED} copied, ${SKIPPED} skipped)"

# ---------------------------------------------------------------------------
# Step 4: Create empty context directories + skeleton files
# ---------------------------------------------------------------------------
step "4/5 — Creating context directories and skeleton files..."

# Create all required directories
CONTEXT_DIRS=(
  "${BASE_DIR}/context/rules"
  "${BASE_DIR}/context/knowledge"
  "${BASE_DIR}/context/guidelines"
  "${BASE_DIR}/context/skills/planner"
  "${BASE_DIR}/context/skills/requirement"
  "${BASE_DIR}/context/skills/designer"
  "${BASE_DIR}/context/skills/developer"
  "${BASE_DIR}/context/skills/dev_testing"
  "${BASE_DIR}/context/skills/reviewer"
  "${BASE_DIR}/context/skills/healer"
  "${BASE_DIR}/context/skills/git_ops"
  "${BASE_DIR}/workspace"
)

for dir in "${CONTEXT_DIRS[@]}"; do
  mkdir -p "${dir}"
done

ok "Context directories created"

# Run the bootstrap script to generate skeleton context files
info "Running bootstrap script to generate skeleton context files..."
if [[ -f "${BASE_DIR}/adlc_bootstrap.sh" ]]; then
  bash "${BASE_DIR}/adlc_bootstrap.sh" "${PROJECT_NAME}"
  ok "Skeleton context files generated"
else
  warn "Bootstrap script not found — skipping skeleton generation"
  warn "You can run it later: bash ${BASE_DIR}/adlc_bootstrap.sh ${PROJECT_NAME}"
fi

# ---------------------------------------------------------------------------
# Step 5: Set up .gitignore and workspace
# ---------------------------------------------------------------------------
step "5/5 — Configuring .gitignore..."

GITIGNORE_ENTRY="adlc_repo_orchestrator/workspace/"

# Create workspace .gitkeep
if [[ ! -f "${BASE_DIR}/workspace/.gitkeep" ]]; then
  touch "${BASE_DIR}/workspace/.gitkeep"
  ok "Created: ${BASE_DIR}/workspace/.gitkeep"
fi

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
echo -e "${GREEN}ADLC Pipeline porting complete!${NC}"
echo "=============================================="
echo ""
echo "Copied from reference:"
echo "  .github/agents/            — 10 agent instruction files"
echo "  ${BASE_DIR}/"
echo "    ├── configs/pipeline.yaml"
echo "    ├── context/skills/documenter/{feature,bug}.template.md"
echo "    ├── PORTING_GUIDE.md"
echo "    └── adlc_bootstrap.sh"
echo ""
echo "Created for your project:"
echo "  ${BASE_DIR}/"
echo "    ├── context/"
echo "    │   ├── rules/${PROJECT_NAME}_rules.md"
echo "    │   ├── knowledge/{architecture,modules,tech_stack}.md"
echo "    │   ├── guidelines/{coding_patterns,naming_conventions}.md"
echo "    │   └── skills/{planner,requirement,designer,developer,dev_testing,reviewer,healer,git_ops}/"
echo "    └── workspace/.gitkeep"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Customize pipeline.yaml:"
echo "     - Update documentation.space_key and documentation.parent_page_id for Confluence"
echo "     - Uncomment MCP server tools you have (Jira, Confluence, etc.)"
echo "     - Adjust models, temperatures, or disable stages as needed"
echo "  2. Fill in the TODO sections in all skeleton context files"
echo "     (Start with knowledge/architecture.md — most impactful)"
echo "  3. Test: @repo_orchestrator Start task: <description>"
echo ""
echo "See ${BASE_DIR}/PORTING_GUIDE.md for detailed instructions and schemas."
