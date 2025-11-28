import pytest
import sys
import os
import json
import httpx

# Add current dir to sys.path so we can import local modules
sys.path.append(os.path.dirname(__file__))

# Defer dorkmaster import until after sys.path is modified
import dorkmaster
import dork_cli_menu

def test_imports():
    """Simple smoke test to ensure modules import without syntax errors."""
    # This test implicitly passes if the script reaches this point
    # because the imports at the top would have failed otherwise.
    assert dorkmaster is not None
    assert dork_cli_menu is not None

def test_plugin_loading():
    """Test that plugins can be discovered."""
    # Ensure PLUGIN_DIR is correct
    assert os.path.exists(dorkmaster.PLUGIN_DIR)
    plugins = dorkmaster.load_plugins()
    # We added 2 plugins, so we expect at least those
    assert "mega_downloader" in plugins
    assert "telegram_integration" in plugins

def test_default_config_structure():
    """Test that default config has the new keys."""
    cfg = dorkmaster.DEFAULT_CONFIG
    assert "telegram_api_id" in cfg
    assert "searx_pool" in cfg
    assert cfg["private_searxng_url"] == "http://localhost:8080"

# --- Robustness & Edge Case Tests ---

def test_config_resilience_to_missing_keys(tmp_path, mocker):
    """Ensures config loader can handle partial configs and applies defaults."""
    # Create a malformed/incomplete config file
    partial_config_data = {"private_searxng_url": "http://example.com"}
    config_file = tmp_path / "config.json"
    config_file.write_text(json.dumps(partial_config_data))

    # Mock the CONFIG_FILE constant to point to our temp file
    mocker.patch.object(dorkmaster, "CONFIG_FILE", str(config_file))
    
    # Act
    loaded_config = dorkmaster.load_config()
    
    # Assert
    # It should use the value from the partial config
    assert loaded_config["private_searxng_url"] == "http://example.com"
    # It should have fallen back to the default for a missing key
    assert "searx_pool" in loaded_config
    assert loaded_config["searx_pool"] == dorkmaster.DEFAULT_CONFIG["searx_pool"]

def test_analyze_target_handles_network_error(mocker):
    """Ensures analyze_target returns None on a network error instead of crashing."""
    # Mock httpx.get to raise a network error
    mocker.patch("httpx.get", side_effect=httpx.RequestError("Test network error"))
    mock_console_print = mocker.patch("dorkmaster.console.print")
    
    # Act
    result = dorkmaster.analyze_target("http://thissitedoesnotexist.test")
    
    # Assert
    assert result is None
    mock_console_print.assert_any_call("[red]Fetch failed http://thissitedoesnotexist.test: Test network error[/red]")

def test_image_enumerator_no_numeric_pattern():
    """Ensures the image enumerator raises ValueError for URLs with no numbers."""
    enumerator = dorkmaster.ImageEnumerator()
    url = "http://example.com/image_without_number.jpg"
    
    # Assert that the specific exception is raised
    with pytest.raises(ValueError, match="No numeric sequence found in filename."):
        enumerator._extract_brute_pattern(url)

def test_searx_fallback_logic(mocker):
    """Ensures that if all SearxNG instances fail, it falls back to telegram_megahunt."""
    # Mock httpx.Client.get to always fail
    mocker.patch("httpx.Client.get", side_effect=httpx.ConnectError("Connection failed"))
    # Spy on the fallback function
    mock_telegram_hunt = mocker.patch("dorkmaster.telegram_megahunt", return_value=[])
    
    # Act
    dorkmaster.run_searx("test query")
    
    # Assert
    assert mock_telegram_hunt.called
    mock_telegram_hunt.assert_called_once_with("test query", 30)
