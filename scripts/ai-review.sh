#!/usr/bin/env bash

set -euo pipefail

# Source common logic
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# 1. Parse arguments
MODEL=""
CUSTOM_TASK="general review"
NON_INTERACTIVE=false
DRY_RUN=false
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

# 3. Get the staged changes (diff)
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

# Check if there are any changes to review
STAGED_DIFF=$(get_git_diff "$DIFF_ARGS")
if [ -z "$STAGED_DIFF" ]; then
  echo "✅ No changes detected to review."
  exit 0
fi

# Secret detection pre-scan
check_secrets "$STAGED_DIFF"

echo "🤖 $ENGINE ($MODEL) is reviewing your changes..."

# 3. Construct the prompt template
TMP_PROMPT=$(mktemp) || exit 1
trap 'rm -f "$TMP_PROMPT"' EXIT INT TERM

if [[ -f "$REVIEW_PROMPT_PATH" && "$CUSTOM_TASK" == "general review" ]]; then
    cat "$REVIEW_PROMPT_PATH" > "$TMP_PROMPT"
else
    # Fallback to hardcoded template if skill prompt is not found
    cat <<'EOF' > "$TMP_PROMPT"
You are a Senior Code Reviewer. 

### REVIEW SCOPE
Analyze the provided Git Diff focusing on:
1. SECURITY & BUGS: Vulnerabilities, credential leaks, and logic errors.
2. CLEAN CODE: Readability, simplicity, and maintainability.
3. BEST PRACTICES: Language-specific standards and idiomatic patterns.
4. PERFORMANCE: Complexity issues, resource leaks, and bottlenecks.

### SEVERITY & PRIORITY DEFINITIONS
- **CRITICAL (P0)**: Security risks, data loss, or system crashes. (Blocker)
- **HIGH (P1)**: Functional bugs or major violations of best practices. (High Priority)
- **MEDIUM (P2)**: Code smells, poor readability, or suboptimal patterns. (Normal)
- **LOW (P3)**: Purely aesthetic nits, minor naming suggestions, or style. (Optional)

### OUTPUT FORMAT INSTRUCTIONS
1. **STRICT RULE**: Start each issue line with exactly the string: 'ISSUE: [LEVEL]'.
2. **STRICT RULE**: DO NOT use numbering (e.g., '1.', '2.', 'Issue #1').
3. **STRICT RULE**: NO MARKDOWN BOLDING: Never write **ISSUE:**. Use plain text "ISSUE:" only.
4. **STRICT RULE**: NO VISUAL EMBELLISHMENTS: Do not use bullet points or bold text for the headers.

### Template for each issue:
ISSUE: [LEVEL] - [Short Description]
File: `path/to/file/name.ext`
Priority: P[0-3]
* Explanation: Detailed explanation of the root cause.
* Suggestion: Concrete steps to fix the issue.
* Comparison:
[Original Code]
```
// Current problematic code
```

[Suggested Fix]
```
// Corrected code snippet
```

---
EOF
fi

# Append dynamic context safely
{
  printf "\n### CONTEXT\nYour specific task for this session is: %s\n" "$CUSTOM_TASK"
  printf "\nGit Diff to Review:\n"
  echo "$STAGED_DIFF"
} >> "$TMP_PROMPT"

# 4. Dry run or send to AI Engine
if [ "$DRY_RUN" = true ]; then
  echo "--- DRY RUN: Constructed Prompt ---"
  cat "$TMP_PROMPT"
  echo "-----------------------------------"
  exit 0
fi

REVIEW_RESULT=$(call_ai_engine "$ENGINE" "$MODEL" "$TMP_PROMPT")

# Check for empty response
if [ -z "$REVIEW_RESULT" ]; then
  echo "❌ Error: AI engine failed to generate a review response."
  exit 1
fi

# Clean up output (remove leading/trailing whitespace)
REVIEW=$(echo "$REVIEW_RESULT" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

echo ""
echo "📋 COMPREHENSIVE CODE REVIEW RESULTS"
echo "=========================================="
echo "$REVIEW"
echo "=========================================="

# Count actual issues only
criticalCount=$(echo "$REVIEW" | grep -Ei "^ISSUE: \[?CRITICAL\]?" | wc -l | xargs)
highCount=$(echo "$REVIEW" | grep -Ei "^ISSUE: \[?HIGH\]?" | wc -l | xargs)
mediumCount=$(echo "$REVIEW" | grep -Ei "^ISSUE: \[?MEDIUM\]?" | wc -l | xargs)
lowCount=$(echo "$REVIEW" | grep -Ei "^ISSUE: \[?LOW\]?" | wc -l | xargs)

echo ""
echo "📈 REVIEW SUMMARY:"
echo "  🔴 Critical Issues: $criticalCount"
echo "  🟠 High Severity: $highCount"
echo "  🟡 Medium Severity: $mediumCount"
echo "  🟢 Low Severity: $lowCount"
echo ""

# 5. Logic for block/approve
if [ "$criticalCount" -gt 0 ] || [ "$highCount" -gt 0 ] || [ "$mediumCount" -ge 3 ]; then
  [ "$criticalCount" -gt 0 ] && echo "🚫 COMMIT BLOCKED: Critical issues found ($criticalCount)."
  [ "$highCount" -gt 0 ] && echo "🚫 COMMIT BLOCKED: High severity issues found ($highCount)."
  [ "$mediumCount" -ge 3 ] && echo "⚠️  COMMIT BLOCKED: Too many medium issues ($mediumCount found)."
  echo ""
  echo " ✗ COMMIT REJECTED ✗ "
  exit 1
else
  echo "✅ Code review completed. Commit approved!"
  echo ""
  echo " ✓ COMMIT WILL PROCEED ✓ "
  exit 0
fi
