#!/usr/bin/env bash
# test-changelog.sh: Test suite verifying changelog.sh output and categorization.

set -euo pipefail

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

echo "Setting up temporary git repository in $TEST_DIR..."
cd "$TEST_DIR"
git init -b main
git config user.name "Tester"
git config user.email "tester@example.com"

# Create dummy commits
echo "init" > file.txt
git add file.txt
git commit -m "feat(core): initial release of engine"

git tag v0.1.0

echo "feature" >> file.txt
git commit -am "feat(api): add REST endpoints"

echo "fix" >> file.txt
git commit -am "fix(auth): resolve JWT expiration validation"

echo "chore" >> file.txt
git commit -am "chore: update dependencies"

echo "remove" >> file.txt
git commit -am "remove: drop legacy fallback endpoints"

# Run changelog.sh
bash /home/hussain/src/niffler/sandbox_workspaces/gh_claude-builders-bounty_claude-builders-bounty_1/changelog.sh CHANGELOG.md .

# Assertions
echo "Verifying CHANGELOG.md contents..."
grep -q "### Added" CHANGELOG.md || { echo "FAIL: Missing Added section"; exit 1; }
grep -q "### Fixed" CHANGELOG.md || { echo "FAIL: Missing Fixed section"; exit 1; }
grep -q "### Changed" CHANGELOG.md || { echo "FAIL: Missing Changed section"; exit 1; }
grep -q "### Removed" CHANGELOG.md || { echo "FAIL: Missing Removed section"; exit 1; }
grep -q "Changes since v0.1.0" CHANGELOG.md || { echo "FAIL: Missing tag range in header"; exit 1; }

echo "ALL TESTS PASSED!"
cat CHANGELOG.md
