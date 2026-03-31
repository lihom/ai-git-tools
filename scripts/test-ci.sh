#!/usr/bin/env bash

set -euo pipefail

# test-ci.sh: Automated CI verification for ai-git-tools
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "🧪 Running CI Tests for AI Git Tools..."

# 0. Setup Privacy Confirmation for CI
touch "$HOME/.ai-git-tools-confirmed"

# 1. Check Permissions
echo "📁 Checking script permissions..."
for script in "$SCRIPT_DIR"/*.sh "$REPO_DIR"/hooks/* "$REPO_DIR"/setup.sh; do
    if [ ! -x "$script" ]; then
        echo "❌ Error: $script is not executable."
        exit 1
    fi
done
echo "✅ Permissions OK."

# 2. Test Setup Script (Simulation)
echo "🔗 Testing setup script logic..."
TEST_PROJECT=$(mktemp -d)
trap 'rm -rf "$TEST_PROJECT"' EXIT

cd "$TEST_PROJECT"
git init > /dev/null
echo "test" > test.txt
git add test.txt

# Run setup
bash "$REPO_DIR/setup.sh" > /dev/null

# Verify hooks
for hook in pre-commit prepare-commit-msg; do
    if [ ! -L ".git/hooks/$hook" ]; then
        echo "❌ Error: $hook symbolic link not found."
        exit 1
    fi
done
echo "✅ Setup and Hook Linking OK."

# 3. Test Review Script (Dry Run)
echo "🤖 Testing ai-review.sh (Dry Run)..."
for engine in gemini ollama codex; do
    echo "   Testing engine: $engine"
    bash "$SCRIPT_DIR/ai-review.sh" --engine "$engine" --dry-run --non-interactive > /dev/null
done
echo "✅ ai-review.sh Dry Runs OK."

# 4. Test Commit Script (Dry Run)
echo "✍️ Testing ai-commit.sh (Dry Run)..."
for engine in gemini ollama codex; do
    echo "   Testing engine: $engine"
    bash "$SCRIPT_DIR/ai-commit.sh" --engine "$engine" --dry-run --non-interactive > /dev/null
done
echo "✅ ai-commit.sh Dry Runs OK."

echo ""
echo "🎉 All CI Tests Passed!"
exit 0
