#!/usr/bin/env bash
# dedup.sh — deterministic helpers for the intake semantic-dedup index.
# Pinning text+hash here keeps every session's index byte-compatible (same tag/key/format).
# Pure (no network) except dedup_keyword_search. Source me: . ./dedup.sh

# Normalize for hashing: lowercase, collapse whitespace, trim.
_dedup_norm(){ printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -s '[:space:]' ' ' | sed 's/^ //;s/ $//'; }

# Collapse whitespace + trim a single field.
_dedup_trim(){ printf '%s' "$1" | tr -s '[:space:]' ' ' | sed 's/^ //;s/ $//'; }

# Index/display text fed to mem_save: "<title>. <summary>" (title only if summary empty).
dedup_text(){ # title summary
  local t s; t=$(_dedup_trim "$1"); s=$(_dedup_trim "$2")
  if [ -n "$s" ]; then printf '%s. %s' "$t" "$s"; else printf '%s' "$t"; fi
}

# Content hash for change detection: sha256 of normalized text, first 16 hex chars.
dedup_hash(){ # title summary
  _dedup_norm "$(dedup_text "$1" "$2")" | sha256sum | cut -c1-16
}

# Lazy-heal per-item decision. Echoes: missing|fresh|changed|nontext
dedup_decide(){ # in_index(yes|no) lv_changed(yes|no) hash_changed(yes|no)
  if [ "$1" != "yes" ]; then echo missing; return; fi
  if [ "$2" != "yes" ]; then echo fresh; return; fi
  if [ "$3" = "yes" ]; then echo changed; else echo nontext; fi
}

# Keyword fallback search (APIv3 full-text), used when redis-memory is unavailable.
# Echoes matching WP ids, one per line. Requires $U and the $A curl-auth array in scope.
dedup_keyword_search(){ # "query terms" [pageSize]
  local q="$1" n="${2:-5}"
  local filt="[{\"search\":{\"operator\":\"**\",\"values\":[\"$q\"]}}]"
  curl "${A[@]}" -G "$U/work_packages" \
    --data-urlencode "filters=$filt" --data-urlencode "pageSize=$n" \
  | python3 -c "import sys,json;d=json.load(sys.stdin);print('\n'.join(str(e['id']) for e in d['_embedded']['elements']))"
}
