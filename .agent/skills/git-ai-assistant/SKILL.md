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
- `review-*.md`: Various code review styles (e.g., concise, comprehensive, structured).
- `commit-*.md`: Different types of commit message prompts (e.g., basic, detailed).

## How to use

This skill is intended to be used by AI agents to perform high-quality Git operations. The prompts can be read by the agent and used as the basis for interacting with LLM engines like Gemini, Ollama, or Codex.
