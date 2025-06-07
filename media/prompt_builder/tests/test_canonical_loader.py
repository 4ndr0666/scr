import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from canonical_loader import CanonicalParamLoader


class CanonicalLoaderTest(unittest.TestCase):
    def setUp(self):
        self.loader = CanonicalParamLoader("media/prompt_builder")

    def test_validate_param_success(self):
        lighting = self.loader.get_param_options("lighting")[0]
        self.assertTrue(self.loader.validate_param("lighting", lighting))

    def test_validate_param_failure(self):
        self.assertFalse(self.loader.validate_param("lighting", "not_real"))

    def test_assemble_prompt_block(self):
        data = {
            "subject": "hero",
            "age_tag": "adult",
            "gender_tag": "male",
            "action_sequence": "runs forward",
            "camera_moves": [self.loader.get_param_options("camera_move")[0]],
            "lighting": self.loader.get_param_options("lighting")[0],
            "lens": self.loader.get_param_options("lens")[0],
            "environment": self.loader.get_param_options("environment")[0],
            "shadow": self.loader.get_param_options("shadow")[0],
            "detail": self.loader.get_param_options("detail")[0],
        }
        block = self.loader.assemble_prompt_block(data)
        self.assertIn("Subject: hero", block)
        self.assertIn("Action Sequence: runs forward", block)


if __name__ == "__main__":
    unittest.main()
