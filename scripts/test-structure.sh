#!/usr/bin/env bash
# test-structure.sh — structural validation for the plugin's skills, commands,
# hooks, and plugin.json references. No network, no Docker, no mutation.
# Run: bash scripts/test-structure.sh
set -euo pipefail

pass=0; fail=0
ok(){ echo "  PASS: $1"; pass=$((pass+1)); }
no(){ echo "  FAIL: $1"; fail=$((fail+1)); }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# ===========================================================================
echo "== 1. Every directory in skills/ has a SKILL.md =="
# ===========================================================================

for dir in "$ROOT"/skills/*/; do
  name="$(basename "$dir")"
  if [ -f "$dir/SKILL.md" ]; then
    ok "skills/$name/SKILL.md exists"
  else
    no "skills/$name/SKILL.md missing"
  fi
done

# ===========================================================================
echo "== 2. Every SKILL.md has valid YAML frontmatter (name + description) =="
# ===========================================================================

for skill_file in "$ROOT"/skills/*/SKILL.md; do
  rel="${skill_file#$ROOT/}"
  dir_name="$(basename "$(dirname "$skill_file")")"

  # Check frontmatter delimiters exist
  first_line="$(head -1 "$skill_file")"
  if [ "$first_line" != "---" ]; then
    no "$rel: missing opening --- frontmatter delimiter"
    continue
  fi

  # Find closing delimiter (second ---) line number
  closing_line="$(awk 'NR>1 && /^---$/{print NR; exit}' "$skill_file")"
  if [ -z "$closing_line" ]; then
    no "$rel: missing closing --- frontmatter delimiter"
    continue
  fi
  ok "$rel: has frontmatter delimiters"

  # Extract frontmatter (between the two --- lines, exclusive)
  frontmatter="$(sed -n "2,$((closing_line - 1))p" "$skill_file")"

  # Extract name field
  fm_name="$(echo "$frontmatter" | grep -E '^name:' | head -1 | sed 's/^name:[[:space:]]*//')"
  if [ -z "$fm_name" ]; then
    no "$rel: frontmatter missing 'name' field"
  else
    ok "$rel: has name field ($fm_name)"
  fi

  # Extract description field
  fm_desc="$(echo "$frontmatter" | grep -E '^description:' | head -1 | sed 's/^description:[[:space:]]*//')"
  if [ -z "$fm_desc" ]; then
    no "$rel: frontmatter missing 'description' field"
  else
    ok "$rel: has description field"
  fi

  # Description length check (< 1000 chars — generous; descriptions are matching triggers)
  if [ -n "$fm_desc" ]; then
    desc_len="${#fm_desc}"
    if [ "$desc_len" -lt 1000 ]; then
      ok "$rel: description length OK ($desc_len chars)"
    else
      no "$rel: description too long ($desc_len chars, max 1000)"
    fi
  fi
done

# ===========================================================================
echo "== 3. Frontmatter name matches directory name =="
# ===========================================================================

for skill_file in "$ROOT"/skills/*/SKILL.md; do
  rel="${skill_file#$ROOT/}"
  dir_name="$(basename "$(dirname "$skill_file")")"

  closing_line="$(awk 'NR>1 && /^---$/{print NR; exit}' "$skill_file")"
  [ -z "$closing_line" ] && continue

  frontmatter="$(sed -n "2,$((closing_line - 1))p" "$skill_file")"
  fm_name="$(echo "$frontmatter" | grep -E '^name:' | head -1 | sed 's/^name:[[:space:]]*//')"

  if [ "$fm_name" = "$dir_name" ]; then
    ok "$rel: name '$fm_name' matches directory"
  else
    no "$rel: name '$fm_name' does not match directory '$dir_name'"
  fi
done

# ===========================================================================
echo "== 4. SKILL.md has a markdown heading =="
# ===========================================================================

for skill_file in "$ROOT"/skills/*/SKILL.md; do
  rel="${skill_file#$ROOT/}"
  if grep -qE '^#[[:space:]]' "$skill_file"; then
    ok "$rel: has markdown heading"
  else
    no "$rel: no markdown heading found"
  fi
done

# ===========================================================================
echo "== 5. Every command in commands/ is a valid .md file with content =="
# ===========================================================================

cmd_count=0
for cmd_file in "$ROOT"/commands/*; do
  [ -f "$cmd_file" ] || continue
  fname="$(basename "$cmd_file")"
  cmd_count=$((cmd_count + 1))

  # Must be .md
  case "$fname" in
    *.md) ok "commands/$fname: is .md file" ;;
    *)    no "commands/$fname: not a .md file"; continue ;;
  esac

  # Must have content (non-empty)
  if [ ! -s "$cmd_file" ]; then
    no "commands/$fname: file is empty"
    continue
  fi
  ok "commands/$fname: has content"

  # First line should be meaningful (frontmatter --- or a heading)
  first="$(head -1 "$cmd_file")"
  case "$first" in
    ---*|"#"*) ok "commands/$fname: meaningful first line" ;;
    *)         no "commands/$fname: first line not frontmatter or heading ('$first')" ;;
  esac
done

if [ "$cmd_count" -gt 0 ]; then
  ok "commands/ has $cmd_count command file(s)"
else
  no "commands/ has no command files"
fi

# ===========================================================================
echo "== 6. Skills listed in CLAUDE.md Layout section exist as directories =="
# ===========================================================================

# Extract the skills line from the Layout section of CLAUDE.md
# The layout lists skills on lines under "skills/" like:
#   skills/           pm-craft · openproject-pm · ...
claude_md="$ROOT/CLAUDE.md"
if [ -f "$claude_md" ]; then
  # Grab lines that list skill names (after "skills/" in the layout block).
  # The listing can span multiple continuation lines, so grab several lines after the anchor.
  skills_line="$(grep -A5 '^skills/' "$claude_md" | sed '/^commands\//,$d' | tr '·' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' | grep -v '^skills/' | grep -v '^--$')"
  while IFS= read -r skill_name; do
    [ -z "$skill_name" ] && continue
    if [ -d "$ROOT/skills/$skill_name" ]; then
      ok "CLAUDE.md skill '$skill_name' exists in skills/"
    else
      no "CLAUDE.md skill '$skill_name' NOT found in skills/"
    fi
  done <<< "$skills_line"

  # Reverse check: every directory in skills/ is listed in CLAUDE.md
  layout_block="$(grep -A5 '^skills/' "$claude_md" | sed '/^commands\//,$d' || true)"
  for dir in "$ROOT"/skills/*/; do
    dir_name="$(basename "$dir")"
    if echo "$layout_block" | grep -qF "$dir_name"; then
      ok "skills/$dir_name listed in CLAUDE.md Layout"
    else
      no "skills/$dir_name NOT listed in CLAUDE.md Layout"
    fi
  done
else
  no "CLAUDE.md not found"
fi

# ===========================================================================
echo "== 7. plugin.json paths resolve =="
# ===========================================================================

plugin_json="$ROOT/.claude-plugin/plugin.json"
if [ -f "$plugin_json" ]; then
  ok "plugin.json exists"

  # Extract skills path
  skills_path="$(grep '"skills"' "$plugin_json" | sed 's/.*"skills"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/' | sed 's|^\.\/||')"
  if [ -n "$skills_path" ] && [ -d "$ROOT/$skills_path" ]; then
    ok "plugin.json skills path '$skills_path' resolves"
  else
    no "plugin.json skills path '$skills_path' does not resolve"
  fi

  # Extract commands path
  commands_path="$(grep '"commands"' "$plugin_json" | sed 's/.*"commands"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/' | sed 's|^\.\/||')"
  if [ -n "$commands_path" ] && [ -d "$ROOT/$commands_path" ]; then
    ok "plugin.json commands path '$commands_path' resolves"
  else
    no "plugin.json commands path '$commands_path' does not resolve"
  fi

  # Extract hooks path
  hooks_path="$(grep '"hooks"' "$plugin_json" | sed 's/.*"hooks"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/' | sed 's|^\.\/||')"
  if [ -n "$hooks_path" ] && [ -f "$ROOT/$hooks_path" ]; then
    ok "plugin.json hooks path '$hooks_path' resolves"
  else
    no "plugin.json hooks path '$hooks_path' does not resolve"
  fi
else
  no "plugin.json not found at .claude-plugin/plugin.json"
fi

# ===========================================================================
echo "== 8. No duplicate skill names =="
# ===========================================================================

declare -A seen_names
duplicates=0
for skill_file in "$ROOT"/skills/*/SKILL.md; do
  closing_line="$(awk 'NR>1 && /^---$/{print NR; exit}' "$skill_file")"
  [ -z "$closing_line" ] && continue

  frontmatter="$(sed -n "2,$((closing_line - 1))p" "$skill_file")"
  fm_name="$(echo "$frontmatter" | grep -E '^name:' | head -1 | sed 's/^name:[[:space:]]*//')"
  [ -z "$fm_name" ] && continue

  if [ -n "${seen_names[$fm_name]+x}" ]; then
    no "duplicate skill name '$fm_name' in $(basename "$(dirname "$skill_file")") (first in ${seen_names[$fm_name]})"
    duplicates=$((duplicates + 1))
  else
    seen_names["$fm_name"]="$(basename "$(dirname "$skill_file")")"
  fi
done

if [ "$duplicates" -eq 0 ]; then
  ok "no duplicate skill names"
fi

# ===========================================================================
echo "== 9. No orphan test directories =="
# ===========================================================================

orphans=0
for test_dir in "$ROOT"/skills/*/test "$ROOT"/skills/*/tests; do
  [ -d "$test_dir" ] || continue
  parent="$(dirname "$test_dir")"
  parent_name="$(basename "$parent")"
  if [ ! -f "$parent/SKILL.md" ]; then
    no "orphan test dir: skills/$parent_name/$(basename "$test_dir")/ exists but no SKILL.md"
    orphans=$((orphans + 1))
  fi
done

if [ "$orphans" -eq 0 ]; then
  ok "no orphan test directories"
fi

# ===========================================================================
echo "== RESULT: $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
