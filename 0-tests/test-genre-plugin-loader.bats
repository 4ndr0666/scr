#!/usr/bin/env bats

@test "Plugin loader merges plugins with canonical map" {
	mkdir -p genres
	cat >genres/fantasy-monster.json <<EOF2
{
  "genre": "fantasy-monster",
  "actions": ["Monster emerges from cave, looks around, and roars."]
}
EOF2
	run env PYTHONPATH="media/prompt_builder" python3 - <<'PY'
import promptlib
base = {"fantasy": ["Hero acts heroically."]}
plugin = promptlib.load_genre_plugins("genres")
merged = promptlib.merge_action_genres(base, plugin)
assert "fantasy-monster" in merged and merged["fantasy-monster"]
PY
	[ "$status" -eq 0 ]
}
