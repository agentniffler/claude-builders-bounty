#!/usr/bin/env bash
# changelog.sh: Generate a structured CHANGELOG.md from git commit history.
# Categorizes conventional commits into Added, Fixed, Changed, and Removed.
# Supports fetching commits since the latest git tag or all commits if no tags exist.

set -euo pipefail

OUTPUT_FILE="${1:-CHANGELOG.md}"
REPO_DIR="${2:-.}"

cd "$REPO_DIR"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: Directory '$REPO_DIR' is not a git repository." >&2
    exit 1
fi

# Detect latest tag
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [ -n "$LATEST_TAG" ]; then
    RANGE="${LATEST_TAG}..HEAD"
    HEADER="## Changes since ${LATEST_TAG} ($(date +%Y-%m-%d))"
else
    RANGE="HEAD"
    HEADER="## Full Changelog ($(date +%Y-%m-%d))"
fi

TEMP_ADDED=$(mktemp)
TEMP_FIXED=$(mktemp)
TEMP_CHANGED=$(mktemp)
TEMP_REMOVED=$(mktemp)
TEMP_OTHER=$(mktemp)

trap 'rm -f "$TEMP_ADDED" "$TEMP_FIXED" "$TEMP_CHANGED" "$TEMP_REMOVED" "$TEMP_OTHER"' EXIT

# Read commits in reverse chronological order
if [ -n "$LATEST_TAG" ]; then
    COMMITS=$(git log --no-merges --pretty=format:"%h %s" "$RANGE" || true)
else
    COMMITS=$(git log --no-merges --pretty=format:"%h %s" || true)
fi

while IFS= read -r line; do
    [ -z "$line" ] && continue
    hash=$(echo "$line" | awk '{print $1}')
    subject=$(echo "$line" | cut -d' ' -f2-)

    # Categorize by conventional commit prefix or keyword
    if echo "$subject" | grep -qiE "^feat|^add|^new"; then
        clean_subj=$(echo "$subject" | sed -E 's/^(feat(\([^)]+\))?:?|add:?|new:?) *//I')
        echo "- ${clean_subj} ([${hash}])" >> "$TEMP_ADDED"
    elif echo "$subject" | grep -qiE "^fix|^bug"; then
        clean_subj=$(echo "$subject" | sed -E 's/^(fix(\([^)]+\))?:?|bug:?) *//I')
        echo "- ${clean_subj} ([${hash}])" >> "$TEMP_FIXED"
    elif echo "$subject" | grep -qiE "^refactor|^perf|^chore|^style|^update|^change"; then
        clean_subj=$(echo "$subject" | sed -E 's/^(refactor(\([^)]+\))?:?|perf(\([^)]+\))?:?|chore(\([^)]+\))?:?|style(\([^)]+\))?:?|update:?|change:?) *//I')
        echo "- ${clean_subj} ([${hash}])" >> "$TEMP_CHANGED"
    elif echo "$subject" | grep -qiE "^revert|^remove|^deprecate"; then
        clean_subj=$(echo "$subject" | sed -E 's/^(revert(\([^)]+\))?:?|remove:?|deprecate:?) *//I')
        echo "- ${clean_subj} ([${hash}])" >> "$TEMP_REMOVED"
    else
        echo "- ${subject} ([${hash}])" >> "$TEMP_OTHER"
    fi
done <<< "$COMMITS"

# Build output
{
    echo "# Changelog"
    echo ""
    echo "All notable changes to this project are documented in this file."
    echo ""
    echo "$HEADER"
    echo ""

    if [ -s "$TEMP_ADDED" ]; then
        echo "### Added"
        cat "$TEMP_ADDED"
        echo ""
    fi

    if [ -s "$TEMP_FIXED" ]; then
        echo "### Fixed"
        cat "$TEMP_FIXED"
        echo ""
    fi

    if [ -s "$TEMP_CHANGED" ]; then
        echo "### Changed"
        cat "$TEMP_CHANGED"
        echo ""
    fi

    if [ -s "$TEMP_REMOVED" ]; then
        echo "### Removed"
        cat "$TEMP_REMOVED"
        echo ""
    fi

    if [ -s "$TEMP_OTHER" ]; then
        echo "### Other"
        cat "$TEMP_OTHER"
        echo ""
    fi
} > "$OUTPUT_FILE"

echo "Changelog successfully written to $OUTPUT_FILE"
