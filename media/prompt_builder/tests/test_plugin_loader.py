import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from plugin_loader import (
    load_prompt_plugin_categorized,
    load_prompt_plugin_legacy,
)

PLUGIN = (Path(__file__).resolve().parents[1] / "plugins/prompts1.md").resolve()


class PluginLoaderTest(unittest.TestCase):
    def test_legacy_block_count(self):
        blocks = load_prompt_plugin_legacy(PLUGIN)
        self.assertEqual(len(blocks), 26)

    def test_categorized_counts(self):
        cat = load_prompt_plugin_categorized(PLUGIN)
        self.assertEqual(len(cat["uncategorized"]), 26)
        for key in (
            "pose",
            "lighting",
            "lens",
            "camera_move",
            "environment",
            "shadow",
            "detail",
        ):
            self.assertEqual(len(cat[key]), 0)

    def test_deduplication(self):
        cat1 = load_prompt_plugin_categorized(PLUGIN)
        cat2 = load_prompt_plugin_categorized(PLUGIN)
        combined = {k: cat1[k] + cat2[k] for k in cat1}
        # deduplicate manually
        for k, blocks in combined.items():
            seen = set()
            deduped = []
            for b in blocks:
                if b not in seen:
                    seen.add(b)
                    deduped.append(b)
            combined[k] = deduped
        self.assertEqual(len(combined["uncategorized"]), 26)


if __name__ == "__main__":
    unittest.main()
