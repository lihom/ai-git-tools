---
name: git-ai-assistant
description: AI-powered Git assistant for code reviews and commit message generation.
---

# Git AI Assistant Skill

This skill provides a set of AI prompts and logic to assist with Git operations, specifically code reviews and commit message generation.

## Capabilities

- **Code Review**: Analyzes Git diffs for security, performance, code quality, and best practices.
- **Commit Message Generation**: Generates professional 'Conventional Commit' messages based on staged changes.

## Resources

Prompts are located in `resources/prompts/`:
- `review-v1.md`, `review-v2.md`, `review-v3.md`: Different versions of code review prompts.
- `commit-v1.md`, `commit-v2.md`: Different versions of commit message prompts.

## How to use

This skill is intended to be used by AI agents to perform high-quality Git operations. The prompts can be read by the agent and used as the basis for interacting with LLM engines like Gemini, Ollama, or Codex.
