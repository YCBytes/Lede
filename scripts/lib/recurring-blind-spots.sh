#!/usr/bin/env bash
# Detect recurring foldable categories across the last 3 saved reports.
#
# Usage:
#   recurring-blind-spots.sh <reports-dir>
#
# Output: a "RECURRING BLIND SPOTS" block to stdout, or nothing if no pattern.
# Behavior on missing/empty dir: silent (empty output, exit 0).

set -e

DIR="$1"
if [ -z "$DIR" ] || [ ! -d "$DIR" ]; then
  exit 0
fi

# Find the 3 most-recently-modified .md files.
# macOS-compatible: use stat -f for mtime.
recent=$(find "$DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null \
  | xargs -I{} stat -f "%m %N" {} 2>/dev/null \
  | sort -rn \
  | head -3 \
  | awk '{$1=""; sub(/^ /, ""); print}')

if [ -z "$recent" ]; then
  exit 0
fi

# Count files considered (1, 2, or 3).
file_count=$(echo "$recent" | grep -c .)

# Extract unique categories per file (so duplicate categories within one file count once).
# Aggregate across files; print categories appearing in >= 2 files.
all_cats=$(echo "$recent" | while IFS= read -r f; do
  grep -Eo '^- \[foldable \| [^]]+\]' "$f" 2>/dev/null \
    | sed -E 's/^- \[foldable \| ([^]]+)\]/\1/' \
    | sort -u
done)

# Categories with >=2 occurrences (i.e., appeared as unique in 2+ files).
recurring=$(echo "$all_cats" | sort | uniq -c | awk '$1 >= 2 {cnt=$1; sub(/^ +[0-9]+ +/, ""); print $0 "|" cnt}')

if [ -z "$recurring" ]; then
  exit 0
fi

# Emit the block.
echo "RECURRING BLIND SPOTS"
echo "$recurring" | while IFS='|' read -r cat count; do
  [ -z "$cat" ] && continue
  echo "- '$cat' appeared in $count of $file_count recent sessions"
done
