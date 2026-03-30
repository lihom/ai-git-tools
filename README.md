# AI Git Tools: Unified AI-Powered Git Hooks

**AI Git Tools** brings the power of Large Language Models (LLMs) directly into your local development workflow. It simplifies the AI-powered git hook experience by supporting multiple AI engines, including **Gemini**, **Ollama**, and **Codex**.

---

## ✨ Features

* **AI Code Review (`pre-commit`):** Automatically analyzes your staged changes for bugs, security risks, and code smells before you commit.
* **Auto-Commit Messages (`prepare-commit-msg`):** Drafts high-quality, Conventional Commit messages based on your `git diff`.
* **Multi-Engine Support:** Choose between Gemini, Ollama, or Codex.
* **Privacy First:** Everything runs locally (or via your preferred AI provider).
* **Human-in-the-Loop:** The AI suggests, but you always have the final say.

---

## 🚀 Getting Started

### 1. Prerequisites
Install your preferred AI engine CLI:
* **Gemini:** `npm install -g @google/gemini-cli`
* **Ollama:** [Download Ollama](https://ollama.com/)
* **Codex:** Already installed? (Uses `@openai/codex`)

### 2. Installation
Run the setup script from the root of your project:

```bash
chmod +x setup.sh
./setup.sh
```

### 3. Configuration
Create a `.env` file in your project root to configure the AI engine, models, and custom prompts:

```env
# .env
AI_ENGINE=gemini  # options: gemini, ollama, codex
GEMINI_MODEL=gemini-3-flash-preview
OLLAMA_MODEL=gemma3
CODEX_MODEL=gpt-4o

# Optional: Override default prompt templates (Absolute path or relative to project root)
# REVIEW_PROMPT_PATH=/path/to/custom-review.md
# COMMIT_PROMPT_PATH=/path/to/custom-commit.md
```

> The `.env` file is automatically loaded by the hooks. No changes to your shell profile are needed. You can copy `.env.example` to get started.

---

## 🛠️ Usage

### AI Code Review (`pre-commit`)
When you run `git commit`, the AI analyzes your changes. If it detects **Critical** or **High** severity issues, the commit is **blocked**.

* **To bypass:** Run `git commit --no-verify`.

### AI Commit Drafting (`prepare-commit-msg`)
If the review passes, your text editor will open with a pre-filled commit message.

### Manual Run
You can run the review or commit script manually at any time:

```bash
sh ./scripts/ai_review.sh --engine codex
sh ./scripts/ai_commit.sh --engine ollama
```

---

## 📄 License
MIT
