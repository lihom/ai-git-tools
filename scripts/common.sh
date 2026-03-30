#!/usr/bin/env bash

set -euo pipefail

# Ensure common CLI paths are in PATH, especially for non-interactive git hooks
export PATH="$PATH:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# Try to find Node.js global binaries if nvm/npm is used
if [ -d "$HOME/.nvm" ]; then
    # Add current active nvm node version to path if possible
    # This is a bit tricky in a script, but we can try to find the latest version
    NVM_BIN=$(ls -td "$HOME/.nvm/versions/node/"*/bin 2>/dev/null | head -n 1)
    if [ -n "$NVM_BIN" ]; then
        export PATH="$PATH:$NVM_BIN"
    fi
fi

# Add common Node version path safely if it exists
NODE_V22_BIN="$HOME/.nvm/versions/node/v22.18.0/bin"
if [ -d "$NODE_V22_BIN" ]; then
    export PATH="$PATH:$NODE_V22_BIN"
fi

# Always load .env from the ai-git-tools root (the parent of scripts/)
_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_AI_GIT_TOOLS_DIR="$(dirname "$_COMMON_DIR")"
if [ -f "$_AI_GIT_TOOLS_DIR/.env" ]; then
    source "$_AI_GIT_TOOLS_DIR/.env"
fi

# Function to get the default model for a given engine
get_default_model() {
    local engine="$1"
    case "$engine" in
        gemini)
            echo "${GEMINI_MODEL:-gemini-3-flash-preview}"
            ;;
        ollama)
            echo "${OLLAMA_MODEL:-gemma3}"
            ;;
        codex)
            echo "${CODEX_MODEL:-gpt-4o}"
            ;;
        *)
            echo "${GEMINI_MODEL:-gemini-3-flash-preview}"
            ;;
    esac
}

# Initial defaults
AI_ENGINE="${AI_ENGINE:-gemini}"
DEFAULT_MODEL=$(get_default_model "$AI_ENGINE")
EXCLUDE_PATTERN="${AI_EXCLUDE_PATTERN:-":(exclude)package-lock.json" ":(exclude)pnpm-lock.yaml"}"

# Default prompt paths (configurable via .env)
REVIEW_PROMPT_PATH="${REVIEW_PROMPT_PATH:-$_AI_GIT_TOOLS_DIR/.agent/skills/git-ai-assistant/resources/prompts/review-style-gemini-github.md}"
COMMIT_PROMPT_PATH="${COMMIT_PROMPT_PATH:-$_AI_GIT_TOOLS_DIR/.agent/skills/git-ai-assistant/resources/prompts/commit-detailed.md}"

# Centralized input safety validation
validate_input_safety() {
    for var in "$@"; do
        case "$var" in
            *[";\`\$&|><"]*)
                echo "❌ Error: Invalid characters in arguments."
                exit 1
                ;;
        esac
    done
}

# Helper to validate that an argument value is provided and not another flag
validate_arg_value() {
    if [[ -z "$2" || "$2" == -* ]]; then
        echo "❌ Error: $1 requires a value."
        exit 1
    fi
}

# Secret Detection Pre-scan
check_secrets() {
    local diff_text="$1"
    # Basic regex patterns for common secrets
    local secret_patterns="AI_KEY|SECRET|PASSWORD|PRIVATE_KEY|AKIA[0-9A-Z]{16}|SG\.[a-zA-Z0-9_-]{22}|sk_live_[0-9a-zA-Z]{24}|-----BEGIN [A-Z ]+ PRIVATE KEY-----"
    
    if echo "$diff_text" | grep -Ei "$secret_patterns" > /dev/null 2>&1; then
        echo ""
        echo "⚠️  SECURITY WARNING: Potential secrets detected in the staged changes!"
        echo "----------------------------------------------------------------------"
        echo "Detected pattern matching sensitive keywords (e.g., KEY, SECRET, PASSWORD)."
        echo "Aborting AI transmission to prevent accidental data exposure."
        echo "----------------------------------------------------------------------"
        exit 1
    fi
}

# One-time confirmation for cloud-based engines
confirm_cloud_engine() {
    local engine="$1"
    local config_file="$HOME/.ai-git-tools-confirmed"

    if [[ "$engine" == "gemini" || "$engine" == "codex" ]]; then
        if [ ! -f "$config_file" ]; then
            echo ""
            echo "🛡️  DATA PRIVACY NOTICE"
            echo "======================="
            echo "You are using a cloud-based AI engine ($engine)."
            echo "Your git diff will be sent to external providers (Google/OpenAI)."
            echo ""
            
            if [[ -t 0 ]]; then
                read -p "Do you acknowledge the risk of sending proprietary code to cloud providers? (y/N) " CONFIRM
                if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
                    touch "$config_file"
                    echo "✅ Acknowledgement recorded. This notice will not show again."
                else
                    echo "❌ Operation aborted by user."
                    exit 1
                fi
            else
                echo "⚠️  Warning: Cloud engine detected in non-interactive mode without prior acknowledgement."
                echo "Please run this command interactively once to acknowledge the privacy notice,"
                echo "or create the file '$config_file' to skip this check."
                exit 1
            fi
        fi
    fi
}

# Centralized git diff retrieval
get_git_diff() {
    git diff "$@" $EXCLUDE_PATTERN
}

# Abstraction for calling different AI engines
call_ai_engine() {
    local engine="$1"
    local model="$2"
    local prompt_file="$3"

    # Verify command availability
    case "$engine" in
        gemini) 
            if ! command -v gemini >/dev/null 2>&1; then
                echo "❌ Error: 'gemini' CLI not found. Please install it with 'npm install -g @google/gemini-cli'"
                exit 1
            fi
            gemini -m "$model" < "$prompt_file"
            ;;
        ollama)
            if ! command -v ollama >/dev/null 2>&1; then
                echo "❌ Error: 'ollama' CLI not found. Please download and install it from https://ollama.com/"
                exit 1
            fi
            ollama run "$model" < "$prompt_file"
            ;;
        codex)
            if ! command -v codex >/dev/null 2>&1; then
                echo "❌ Error: 'codex' CLI not found in PATH."
                exit 1
            fi
            # Use codex exec for non-interactive execution
            codex exec < "$prompt_file"
            ;;
    esac
}
