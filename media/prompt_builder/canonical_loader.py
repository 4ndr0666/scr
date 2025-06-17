#!/usr/bin/env python3
"""Canonical parameter loader with hot reload for promptlib options."""
from __future__ import annotations

import importlib
import os
from pathlib import Path
from types import ModuleType
from typing import Any, Dict, Iterable, List


class CanonicalParamLoader:
    """Load canonical parameters from ``promptlib`` with optional plugin packs.

    Parameters are reloaded automatically if any source file changes. This avoids
    manual restarts and keeps the parameter set current.
    """

    def __init__(self, library_dir: str = "media/prompt_builder") -> None:
        self.library_dir = Path(library_dir).resolve()
        self.module: ModuleType | None = None
        self.mtimes: Dict[Path, float] = {}
        self.params: Dict[str, List[str]] = {}
        self._load()

    def _load(self) -> None:
        """Load or reload ``promptlib`` and update parameter mappings."""
        if self.module is None:
            import promptlib  # type: ignore

            self.module = promptlib
        else:
            self.module = importlib.reload(self.module)

        self.params = {
            "pose_tag": list(getattr(self.module, "POSE_TAGS", [])),
            "camera_move": list(getattr(self.module, "CAMERA_OPTIONS", [])),
            "lighting": list(getattr(self.module, "LIGHTING_OPTIONS", [])),
            "lens": list(getattr(self.module, "LENS_OPTIONS", [])),
            "environment": list(getattr(self.module, "ENVIRONMENT_OPTIONS", [])),
            "shadow": list(getattr(self.module, "SHADOW_OPTIONS", [])),
            "detail": list(getattr(self.module, "DETAIL_PROMPTS", [])),
            "age_group": list(getattr(self.module, "AGE_GROUP_OPTIONS", [])),
            "gender": list(getattr(self.module, "GENDER_OPTIONS", [])),
            "orientation": list(getattr(self.module, "ORIENTATION_OPTIONS", [])),
            "expression": list(getattr(self.module, "EXPRESSION_OPTIONS", [])),
            "shot_framing": list(getattr(self.module, "SHOT_FRAMING_OPTIONS", [])),
            "action_sequence": list(
                getattr(self.module, "ACTION_SEQUENCE_OPTIONS", [])
            ),
        }
        self._record_mtimes()

    def _record_mtimes(self) -> None:
        """Record modification times for ``library_dir`` contents."""
        self.mtimes = {}
        for root, _dirs, files in os.walk(self.library_dir):
            for name in files:
                path = Path(root) / name
                if path.suffix.lower() in {
                    ".md",
                    ".txt",
                    ".json",
                    ".yml",
                    ".yaml",
                    ".py",
                }:
                    try:
                        self.mtimes[path] = path.stat().st_mtime
                    except FileNotFoundError:
                        continue

    def _check_reload(self) -> None:
        """Reload parameters if any watched file changed."""
        for path, old_mtime in list(self.mtimes.items()):
            try:
                new_mtime = path.stat().st_mtime
            except FileNotFoundError:
                new_mtime = -1
            if new_mtime != old_mtime:
                self._load()
                break

    def get_param_options(self, param_name: str) -> List[str]:
        """Return the option list for ``param_name``."""
        self._check_reload()
        return list(self.params.get(param_name, []))

    def validate_param(self, param_name: str, value: Any) -> bool:
        """Return ``True`` if ``value`` is canonical for ``param_name``."""
        options = set(self.get_param_options(param_name))
        if isinstance(value, Iterable) and not isinstance(value, (str, bytes)):
            return all(str(v) in options for v in value)
        return str(value) in options

    def assemble_prompt_block(self, data: Dict[str, Any]) -> str:
        """Assemble a Hailuo-compliant prompt block from ``data``."""
        self._check_reload()
        required = [
            "subject",
            "age_tag",
            "gender_tag",
            "orientation",
            "expression",
            "action_sequence",
            "camera_moves",
            "lighting",
            "lens",
            "shot_framing",
            "environment",
            "shadow",
            "detail",
        ]
        for field in required:
            if field not in data:
                raise ValueError(f"Missing required parameter: {field}")
        if not self.validate_param("camera_move", data["camera_moves"]):
            raise ValueError("Invalid camera moves")
        if not self.validate_param("orientation", data["orientation"]):
            raise ValueError("Invalid orientation option")
        if not self.validate_param("expression", data["expression"]):
            raise ValueError("Invalid expression option")
        if not self.validate_param("lighting", data["lighting"]):
            raise ValueError("Invalid lighting option")
        if not self.validate_param("lens", data["lens"]):
            raise ValueError("Invalid lens option")
        if not self.validate_param("shot_framing", data["shot_framing"]):
            raise ValueError("Invalid shot framing option")
        if not self.validate_param("environment", data["environment"]):
            raise ValueError("Invalid environment option")
        if not self.validate_param("shadow", data["shadow"]):
            raise ValueError("Invalid shadow option")
        if not self.validate_param("detail", data["detail"]):
            raise ValueError("Invalid detail option")
        build = getattr(self.module, "build_hailuo_prompt")
        return build(
            subject=data["subject"],
            age_tag=data["age_tag"],
            gender_tag=data["gender_tag"],
            orientation=data["orientation"],
            expression=data["expression"],
            action_sequence=data["action_sequence"],
            camera_moves=list(data["camera_moves"]),
            lighting=data["lighting"],
            lens=data["lens"],
            shot_framing=data["shot_framing"],
            environment=data["environment"],
            detail=data["detail"],
        )


def load_canonical_params(
    library_dir: str = "media/prompt_builder",
) -> CanonicalParamLoader:
    """Convenience function returning a loader instance."""
    return CanonicalParamLoader(library_dir)


__all__ = [
    "CanonicalParamLoader",
    "load_canonical_params",
]
