#!/usr/bin/env bash

set -euo pipefail

# Source common logic
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# 1. Parse arguments
MODEL=""
CUSTOM_TASK="general commit"
NON_INTERACTIVE=false
DRY_RUN=false
OUTPUT_FILE=""
ENGINE="$AI_ENGINE"

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --prompt) 
      validate_arg_value "$1" "$2"
      CUSTOM_TASK="$2"; shift ;;
    --prompt-file) 
      validate_arg_value "$1" "$2"
      if [[ -f "$2" ]]; then
        CUSTOM_TASK=$(cat "$2")
      else
        echo "❌ Error: File $2 not found or inaccessible."
        exit 1
      fi
      shift ;;
    --model)  
      validate_arg_value "$1" "$2"
      MODEL="$2"; shift ;;
    --engine)
      validate_arg_value "$1" "$2"
      ENGINE="$2"; shift ;;
    --non-interactive)
      NON_INTERACTIVE=true ;;
    --dry-run)
      DRY_RUN=true ;;
    --output)
      validate_arg_value "$1" "$2"
      OUTPUT_FILE="$2"; shift ;;
    *) echo "❌ Error: Invalid parameter: $1"; exit 1 ;;
  esac
  shift
done

# If model was not explicitly provided, get the default for the selected engine
if [ -z "$MODEL" ]; then
  MODEL=$(get_default_model "$ENGINE")
fi

# 2. Privacy Confirmation for Cloud Engines
confirm_cloud_engine "$ENGINE"

# 3. Get the staged changes
if [ "$NON_INTERACTIVE" = true ]; then
  DIFF_ARGS="--cached"
else
  if [[ -t 0 ]]; then
    read -p "please enter your diff commit id or branch (default: --cached): " DIFF_INPUT
    DIFF_ARGS="${DIFF_INPUT:-"--cached"}"
  else
    DIFF_ARGS="--cached"
  fi
fi

# Input Safety Validation
validate_input_safety "$DIFF_ARGS" "$MODEL" "$CUSTOM_TASK" "$ENGINE"

# Check if there are any changes to commit
STAGED_DIFF=$(get_git_diff "$DIFF_ARGS")
if [ -z "$STAGED_DIFF" ]; then
  echo "❌ Error: No changes staged for commit."
  exit 1
fi

# Secret detection pre-scan
check_secrets "$STAGED_DIFF"

echo "🤖 $ENGINE ($MODEL) is drafting your commit message..."

# 3. Construct the AI Prompt
TMP_PROMPT=$(mktemp) || exit 1
trap 'rm -f "$TMP_PROMPT"' EXIT INT TERM

if [[ -f "$COMMIT_PROMPT_PATH" && "$CUSTOM_TASK" == "general commit" ]]; then
    cat "$COMMIT_PROMPT_PATH" > "$TMP_PROMPT"
else
    # Fallback to hardcoded template if skill prompt is not found
    cat <<'EOF' > "$TMP_PROMPT"
You are an expert Git manager. Write a professional 'Conventional Commit' message based on the provided Git Diff.

### INSTRUCTIONS
1. **Format**: Use the format: '<type>: <description>'
2. **Tone**: Use the imperative mood (e.g., 'fix' instead of 'fixed', 'add' instead of 'added').
3. **Length**: Keep the message concise and under 72 characters (One-liner).
4. **Strict Rule**: Output ONLY the commit message. DO NOT include any preamble, explanations, or quotes.

### TYPE DEFINITIONS
Choose the most appropriate type:
- **feat**: A new feature or significant change.
- **fix**: A bug fix.
- **docs**: Changes only to documentation.
- **style**: Formatting, missing semi-colons, etc. (No logic change).
- **refactor**: Code changes that neither fix a bug nor add a feature.
- **perf**: A code change that improves performance.
- **test**: Adding missing tests or correcting existing tests.
- **build**: Changes that affect the build system or external dependencies.
- **ci**: Changes to CI configuration files and scripts.
- **chore**: Other changes that don't modify src or test files.
- **revert**: Reverts a previous commit.

—
EOF
fi

# Append dynamic context safely
{
  printf "\n1. **Specific Task**: %s\n" "$CUSTOM_TASK"
  printf "\nGit Diff to commit:\n"
  echo "$STAGED_DIFF"
} >> "$TMP_PROMPT"

# 4. Dry run or send to AI Engine
if [ "$DRY_RUN" = true ]; then
  echo "--- DRY RUN: Constructed Prompt ---"
  cat "$TMP_PROMPT"
  echo "-----------------------------------"
  exit 0
fi

AI_MSG=$(call_ai_engine "$ENGINE" "$MODEL" "$TMP_PROMPT")

# 5. Output the AI message
if [ -n "$AI_MSG" ]; then
    # Clean AI message (remove potential markdown markers if engine fails to follow instructions)
    AI_MSG=$(echo "$AI_MSG" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^`//' -e 's/`$//')
    
    if [ -n "$OUTPUT_FILE" ]; then
        TEMP_MSG=$(mktemp) || exit 1
        {
          echo "$AI_MSG"
          echo ""
          echo "# --- AI Generated Message Above ---"
          if [ -f "$OUTPUT_FILE" ]; then
            cat "$OUTPUT_FILE"
          fi
        } > "$TEMP_MSG" && mv "$TEMP_MSG" "$OUTPUT_FILE"
    else
        echo "$AI_MSG"
        echo ""
        echo "# --- AI Generated Message Above ---"
    fi
else
    echo "⚠️ Warning: AI engine failed to generate a commit message."
fi
