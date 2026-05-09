#!/usr/bin/env bash
# Build a ~2KB snapshot of the project's tech stack and key source files.
#
# Usage:
#   extract-project-state.sh <project-dir>
#
# Output: human-readable text, hard-capped at 2048 bytes (truncated with "...").

set -e

DIR="$1"
if [ -z "$DIR" ] || [ ! -d "$DIR" ]; then
  echo "extract-project-state.sh: directory not found: $DIR" >&2
  exit 1
fi

cd "$DIR"

# NOTE: do not emit a section header here — lede.sh wraps this output inside a
# "=== PROJECT STATE AT /assess ===" section. Emitting one here would duplicate it.
OUT=""

# Section 1: package manifest detection.
manifest_found=0
for mf in package.json pyproject.toml Cargo.toml go.mod requirements.txt Gemfile; do
  if [ -f "$mf" ]; then
    manifest_found=1
    case "$mf" in
      package.json)
        deps=$(jq -r '(.dependencies // {}) + (.devDependencies // {}) | keys | join(", ")' "$mf" 2>/dev/null || echo "")
        OUT="${OUT}stack: package.json"
        if [ -n "$deps" ]; then OUT="${OUT} ($deps)"; fi
        OUT="${OUT}\n"
        ;;
      pyproject.toml)
        # Capture dependency lines (rough — first 200 chars of [project]/[tool.poetry] dependencies).
        deps=$(awk '/^\[project\]|^\[tool\.poetry\]/,/^\[/{print}' "$mf" | grep -E 'dependencies|^\s*"' | head -20 | tr '\n' ' ')
        OUT="${OUT}stack: pyproject.toml (${deps:0:200})\n"
        ;;
      Cargo.toml|go.mod|requirements.txt|Gemfile)
        head=$(head -c 300 "$mf" | tr '\n' ' ')
        OUT="${OUT}stack: $mf ($head)\n"
        ;;
    esac
    break
  fi
done

if [ "$manifest_found" = 0 ]; then
  OUT="${OUT}stack: no manifest found in $DIR\n"
fi

# Section 2: signal-bearing config files.
configs=""
for cfg in tailwind.config.js tailwind.config.ts tailwind.config.cjs tsconfig.json next.config.js next.config.ts vite.config.js vite.config.ts .eslintrc .eslintrc.json .eslintrc.js; do
  if [ -f "$cfg" ]; then
    if [ -n "$configs" ]; then configs="${configs}, "; fi
    configs="${configs}${cfg}"
  fi
done
if [ -n "$configs" ]; then
  OUT="${OUT}config: $configs\n"
fi

# Section 3: top-level source files (skip noise).
src_files=$(find . -maxdepth 3 -type f \
  \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.rb" \) \
  -not -path "./node_modules/*" \
  -not -path "./.git/*" \
  -not -path "./dist/*" \
  -not -path "./build/*" \
  -not -path "./target/*" \
  2>/dev/null \
  | head -20 \
  | while read -r f; do
      lines=$(wc -l < "$f" 2>/dev/null | tr -d ' ' || echo "?")
      echo "${f#./} (${lines} lines)"
    done \
  | tr '\n' ', ' \
  | sed 's/, $//')

if [ -n "$src_files" ]; then
  OUT="${OUT}source files: $src_files\n"
fi

# Print and hard-cap at 2048 bytes.
printed=$(printf '%b' "$OUT")
if [ "${#printed}" -gt 2048 ]; then
  printed="${printed:0:2045}..."
fi
printf '%s' "$printed"
