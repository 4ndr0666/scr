import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from promptlib import apply_deakins_lighting


class PromptLibTest(unittest.TestCase):
    def test_apply_deakins_lighting(self):
        sample = (
            "> {\n"
            "    Example line.\n"
            "    Lighting: test lighting.\n"
            "    Shadow Quality: hard.\n"
            "}"
        )
        result = apply_deakins_lighting(sample)
        self.assertNotIn("test lighting", result)
        self.assertIn("Deakins lighting augmentation", result)


if __name__ == "__main__":
    unittest.main()
