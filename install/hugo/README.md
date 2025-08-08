# Hugo

Here’s the exact, safe sequence to publish the content (remove `draft: true`), build, and verify. Run these from the repo root.

---

# 1) Flip drafts to published (idempotent)

```bash
# Show all files that currently have draft: true (you already saw these)
rg -n '^draft:\s*true$' content || echo 'No draft: true lines found.'

# Replace ONLY the exact line "draft: true" with "draft: false" across content/*.md
# This is idempotent: running it again makes no further changes.
find content -type f -name '*.md' -exec sed -i -E 's/^draft:\s*true$/draft: false/' {} +

# Verify there are no remaining draft:true lines
rg -n '^draft:\s*true$' content || echo 'All drafts cleared.'
```

# 2) Commit and push the content changes

```bash
git add content
git commit -m "Publish sections: remove draft flags and build"
git push origin main
```

That push will trigger your GitHub Actions build → artifact upload → Pages deploy. (You already have this wiring working.)

---

# 3) Verify the live site (after the workflow completes)

Give Pages \~30–60s after “Reported success” then:

```bash
# Confirm the live /scripts returns 200
curl -I https://4ndr0666.github.io/4ndr0site/scripts/ | sed -n '1p'

# Fetch the page to confirm it’s not empty
curl -sS https://4ndr0666.github.io/4ndr0site/scripts/ -o /tmp/live-scripts.html
test -s /tmp/live-scripts.html && echo "OK: live /scripts has content" || echo "ERROR: live /scripts is empty"
```

If you still get 404 after a successful deploy:

* Hard-refresh your browser (Ctrl+Shift+R).
* Double-check your workflow’s **build** step is *not* using `hugo` without `-D` if you kept drafts.
* Ensure the artifact upload path is `./public`.
