---
name: generate-changelog
description: Generate a structured CHANGELOG.md from git commit history categorized into Added, Fixed, Changed, and Removed.
---

# Generate Changelog Skill

Automatically inspects the local git commit history and produces a standardized, human-readable `CHANGELOG.md`.

## Capabilities
1. Analyzes commit messages since the most recent git tag (or from inception if unversioned).
2. Auto-sorts entries into conventional groups:
   - Added: `feat:`, `add:`, `new:`
   - Fixed: `fix:`, `bug:`
   - Changed: `refactor:`, `perf:`, `chore:`, `style:`, `update:`
   - Removed: `revert:`, `remove:`, `deprecate:`
3. Formats commit hashes with markdown links and clean messages without noisy prefixes.

## Usage
Run directly from terminal:
```bash
bash changelog.sh [OUTPUT_FILE] [REPO_PATH]
```
Or execute within Claude Code:
```
/generate-changelog
```
