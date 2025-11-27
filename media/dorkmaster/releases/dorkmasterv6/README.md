# Ψ-4ndr0666 DORKMASTER v6

**The Apex Predator of OSINT & Leak Reconnaissance.**

Dorkmaster v6 is the definitive fusion of advanced search intelligence, asynchronous asset enumeration, and modular weaponization. It is designed for researchers, red teamers, and OSINT analysts who require speed, stealth, and depth.

## ⚡ Key Capabilities

*   **Asynchronous Core:** Built on `httpx` and `asyncio` for blazing fast, non-blocking operations.
*   **Advanced Dorking:** Integrated arsenal of 100+ high-yield Google Dorks (Leaks, Media, Logs, Exposed Configs).
*   **Image Enumeration:**
    *   **Brute-Force:** Intelligent pattern prediction for sequential media scraping.
    *   **Recursive Crawler:** Spider-bot that traverses domains to extract assets.
*   **Reddit Ripper:** High-speed subreddit media extractor with sorting and limiting.
*   **Telegram Hunter:** API-driven scraper for public Telegram channels (requires API keys).
*   **Mega.nz Downloader:** Integrated batch downloader for Mega links (requires `megadl`).
*   **SearxNG Integration:** Configurable private/public meta-search engine pooling.
*   **XDG Compliance:** Clean configuration management (`~/.config/dorkmaster`).

## 🛠️ Installation

### Prerequisites
*   **Python 3.8+**
*   **System Tools:** `aria2c` (recommended for batch downloads), `megadl` (optional, for Mega plugin).

### Setup
1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-repo/dorkmaster.git
    cd dorkmaster/releases/dorkmasterv6_refactored
    ```

2.  **Install Dependencies:**
    It is recommended to use a virtual environment.
    ```bash
    python3 -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt
    ```

3.  **Launch:**
    ```bash
    python3 dorkmaster.py
    ```

## ⚙️ Configuration

On first run, Dorkmaster creates a default configuration file at:
`~/.config/dorkmaster/config.json` (Linux/Mac) or `%LOCALAPPDATA%\dorkmaster\config.json` (Windows).

**Key Settings:**
*   `telegram_api_id` / `telegram_api_hash`: Required for the Telegram Hunter plugin. Get these from [my.telegram.org](https://my.telegram.org).
*   `private_searxng_url`: URL of your private SearxNG instance (default: `http://localhost:8080`).
*   `searx_pool`: List of public SearxNG instances to rotate through.

## 🎮 Usage Guide

**Main Menu:**
1.  **Dork & Hunt:** Select a target and category (Media, Docs, Env Files). The tool queries SearxNG/Google and results are saved to the session.
2.  **Brute-Force Enum:** Provide a sample URL (e.g., `site.com/img_001.jpg`). The tool detects the pattern and asynchronously checks `002`...`100`.
3.  **Recursive Crawler:** Crawl a URL to depth `N` and extract all images/media.
4.  **Reddit Ripper:** Download top/hot images from any subreddit.
5.  **Plugins:** Access specialized modules (Telegram scraper, Mega downloader).
6.  **Settings:** View/Edit config on the fly.

**Plugins:**
*   **Telegram Integration:** Searches public channels for keywords (e.g., "onlyfans mega"). Requires valid API credentials in `config.json`.
*   **Mega Downloader:** Batch downloads a list of Mega.nz links using the `megadl` system binary.

## ⚠️ Disclaimer & OpSec

**AUTHOR IS NOT RESPONSIBLE FOR MISUSE.**
This tool is for educational and defensive security research purposes only.

*   **OpSec:** Always use a VPN or Tor when scraping.
*   **Legal:** Do not scrape illegal content or violate Terms of Service of target platforms.
*   **Safety:** Running this tool against unauthorized targets may be illegal in your jurisdiction.

**Ψ-4ndr0666 // END OF LINE**
