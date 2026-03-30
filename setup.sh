#!/bin/bash

# setup.sh for ai-git-tools
set -e

# 1. Determine the path of this repository
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$REPO_DIR/hooks"

# 2. Check if we are inside a Git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "❌ Error: Not a git repository. Please run this script from the root of your project."
    exit 1
fi

GIT_HOOKS_DIR="$(git rev-parse --git-path hooks)"

echo "🚀 Setting up AI Git Tools..."

# 3. Create symbolic links
for hook in pre-commit prepare-commit-msg; do
    TARGET="$GIT_HOOKS_DIR/$hook"
    SOURCE="$HOOKS_DIR/$hook"
    
    if [ -f "$TARGET" ] || [ -L "$TARGET" ]; then
        echo "⚠️  Found existing $hook. Backing up to $hook.bak"
        mv "$TARGET" "$TARGET.bak"
    fi
    
    ln -s "$SOURCE" "$TARGET"
    chmod +x "$SOURCE"
    echo "✅ Linked $hook"
done

echo ""
echo "🎉 AI Git Tools successfully installed!"
echo "--------------------------------------------------"
echo "To configure your AI engine, set the following environment variables:"
echo "  export AI_ENGINE='gemini' # options: gemini, ollama, codex"
echo "  export GEMINI_MODEL='gemini-3-flash-preview'"
echo "  export OLLAMA_MODEL='gemma3'"
echo "  export CODEX_MODEL='gpt-4o'"
echo "--------------------------------------------------"
echo "Happy hacking! 🤖"
