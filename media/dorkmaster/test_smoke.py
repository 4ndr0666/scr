import pytest
import sys
import os
import json

# Add current dir to sys.path so we can import local modules
sys.path.append(os.path.dirname(__file__))

def test_imports():
    """Simple smoke test to ensure modules import without syntax errors."""
    try:
        import dorkmaster
        import dork_cli_menu
    except ImportError as e:
        pytest.fail(f"Failed to import modules: {e}")
    except SyntaxError as e:
        pytest.fail(f"Syntax error in modules: {e}")

def test_plugin_loading():
    """Test that plugins can be discovered."""
    import dorkmaster
    # Ensure PLUGIN_DIR is correct
    assert os.path.exists(dorkmaster.PLUGIN_DIR)
    plugins = dorkmaster.load_plugins()
    # We added 2 plugins, so we expect at least those
    assert "mega_downloader" in plugins
    assert "telegram_integration" in plugins

def test_default_config_structure():
    """Test that default config has the new keys."""
    import dorkmaster
    cfg = dorkmaster.DEFAULT_CONFIG
    assert "telegram_api_id" in cfg
    assert "searx_pool" in cfg
    assert cfg["private_searxng_url"] == "http://localhost:8080"
