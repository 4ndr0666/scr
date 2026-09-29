from __future__ import annotations

import importlib.util
import stat
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent
MODULE_PATH = ROOT / "4ndr0pac"
spec = importlib.util.spec_from_file_location("fourndropac", MODULE_PATH)
assert spec and spec.loader
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def make_backend(tmp: Path) -> tuple[Path, Path]:
    log = tmp / "backend.log"
    backend = tmp / "fake-backend.sh"
    backend.write_text(
        "#!/usr/bin/env bash\n"
        "printf '%s\\n' \"$*\" >> \"$BACKEND_LOG\"\n"
        "exit 7\n",
        encoding="utf-8",
    )
    backend.chmod(stat.S_IRUSR | stat.S_IWUSR | stat.S_IXUSR)
    return backend, log


def test_dangerous_one_shot_requires_confirmation() -> None:
    with TemporaryDirectory() as directory:
        backend, log = make_backend(Path(directory))
        with patch("builtins.input", return_value="n"):
            rc = module.one_shot(backend, ["Remove", "Packages"], [], False)
        assert rc == module.EXIT_ABORT
        assert not log.exists()


def test_dangerous_one_shot_executes_only_after_confirmation(monkeypatch) -> None:
    with TemporaryDirectory() as directory:
        backend, log = make_backend(Path(directory))
        monkeypatch.setenv("BACKEND_LOG", str(log))
        with patch("builtins.input", return_value="yes"):
            rc = module.one_shot(backend, ["Remove", "Packages"], ["pkg-a"], False)
        assert rc == 7
        assert log.read_text(encoding="utf-8").splitlines() == ["r pkg-a"]


def test_safe_one_shot_propagates_backend_status(monkeypatch) -> None:
    with TemporaryDirectory() as directory:
        backend, log = make_backend(Path(directory))
        monkeypatch.setenv("BACKEND_LOG", str(log))
        rc = module.one_shot(backend, ["Package", "Info"], ["pkg-a"], False)
        assert rc == 7
        assert log.read_text(encoding="utf-8").splitlines() == ["p pkg-a"]


def test_dry_run_never_prompts_or_executes(monkeypatch, capsys) -> None:
    with TemporaryDirectory() as directory:
        backend, log = make_backend(Path(directory))
        monkeypatch.setenv("BACKEND_LOG", str(log))
        with patch("builtins.input", side_effect=AssertionError("dry-run prompted")):
            rc = module.one_shot(backend, ["Remove", "Packages"], ["pkg-a"], True)
        assert rc == module.EXIT_OK
        assert not log.exists()
        assert "[dry-run]" in capsys.readouterr().out


def test_numeric_dangerous_alias_is_protected(monkeypatch) -> None:
    with TemporaryDirectory() as directory:
        backend, log = make_backend(Path(directory))
        monkeypatch.setenv("BACKEND_LOG", str(log))
        with patch("builtins.input", return_value="n"):
            rc = module.one_shot(backend, ["6"], [], False)
        assert rc == module.EXIT_OK
        assert log.read_text(encoding="utf-8").splitlines() == ["l"]

        with patch("builtins.input", return_value="n"):
            rc = module.one_shot(backend, ["Remove Packages"], [], False)
        assert rc == module.EXIT_ABORT
