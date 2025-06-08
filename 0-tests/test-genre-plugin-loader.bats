#!/usr/bin/env bats

@test "Plugin loader merges plugins with canonical map" {
	mkdir -p genres
	cat >genres/fantasy-monster.json <<EOF2
{
  "genre": "fantasy-monster",
  "actions": ["Monster emerges from cave, looks around, and roars."]
}
EOF2
        run env PYTHONPATH="$BATS_TEST_DIRNAME/../media/prompt_builder" python3 - <<'PY'
import promptlib
base = {"fantasy": ["Hero acts heroically."]}
plugin = promptlib.load_genre_plugins("genres")
merged = promptlib.merge_action_genres(base, plugin)
assert "fantasy-monster" in merged and merged["fantasy-monster"]
PY
	[ "$status" -eq 0 ]
}

@test "Loading identical plugins twice deduplicates actions" {
	mkdir -p genres
	cat >genres/dup1.json <<EOF
{
  "genre": "repeat",
  "actions": ["roar loudly"]
}
EOF
	cp genres/dup1.json genres/dup2.json
        run env PYTHONPATH="$BATS_TEST_DIRNAME/../media/prompt_builder" python3 - <<'PY'
import promptlib
plugin = promptlib.load_genre_plugins("genres")
assert plugin.get("repeat") == ["roar loudly"]
PY
        [ "$status" -eq 0 ]
}

@test "plugin_loader CLI outputs JSON" {
        run python3 "$BATS_TEST_DIRNAME/../media/prompt_builder/plugin_loader.py" --json "$BATS_TEST_DIRNAME/../media/prompt_builder/plugins/prompts1.md"
        [ "$status" -eq 0 ]
        [[ "$output" == \{* ]]
}
