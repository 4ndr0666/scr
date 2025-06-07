import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from promptlib import (
    build_hailuo_prompt,
    CAMERA_OPTIONS,
    LIGHTING_OPTIONS,
    LENS_OPTIONS,
    ENVIRONMENT_OPTIONS,
    DETAIL_PROMPTS,
    ORIENTATION_OPTIONS,
    EXPRESSION_OPTIONS,
    SHOT_FRAMING_OPTIONS,
)


class HailuoPromptTest(unittest.TestCase):
    def test_invalid_camera_move(self):
        with self.assertRaises(ValueError):
            build_hailuo_prompt(
                subject="hero",
                age_tag="adult",
                gender_tag="male",
                orientation=ORIENTATION_OPTIONS[0],
                expression=EXPRESSION_OPTIONS[0],
                action_sequence="runs forward",
                camera_moves=["fly around"],
                lighting=LIGHTING_OPTIONS[0],
                lens=LENS_OPTIONS[0],
                shot_framing=SHOT_FRAMING_OPTIONS[0],
                environment=ENVIRONMENT_OPTIONS[0],
                detail=DETAIL_PROMPTS[0],
            )

    def test_prompt_construction(self):
        result = build_hailuo_prompt(
            subject="hero",
            age_tag="adult",
            gender_tag="male",
            orientation=ORIENTATION_OPTIONS[0],
            expression=EXPRESSION_OPTIONS[0],
            action_sequence="runs forward",
            camera_moves=[CAMERA_OPTIONS[0], CAMERA_OPTIONS[1]],
            lighting=LIGHTING_OPTIONS[0],
            lens=LENS_OPTIONS[0],
            shot_framing=SHOT_FRAMING_OPTIONS[0],
            environment=ENVIRONMENT_OPTIONS[0],
            detail=DETAIL_PROMPTS[0],
        )
        self.assertIn("Subject: hero.", result)
        self.assertIn(f"Camera: [{CAMERA_OPTIONS[0]}, {CAMERA_OPTIONS[1]}].", result)
        self.assertIn("Orientation", result)


if __name__ == "__main__":
    unittest.main()
