#!/usr/bin/env bats

@test "codex-merge-clean.sh removes all merge artifacts and keeps new content" {
	cat >testfile <<EOF
foo
<<<<<<<<<<<<<<<<<<<CODEX_2023_foo_bar
new segment
=========================
old segment
>>>>>>>>>>>>>>>>>Main
bar
EOF
	run "$BATS_TEST_DIRNAME/codex-merge-clean.sh" testfile
	[ "$status" -eq 0 ]
	diff -u <(cat testfile) <(echo -e "foo\nnew segment\nbar")
}
