.PHONY: all venv clean generate prompt interactive enumerate crawl test

# --- Variables ---
VENV := .venv
PYTHON := $(shell if [ -x "$(VENV)/bin/python" ]; then echo "$(VENV)/bin/python"; else command -v python3; fi)
PIP := $(VENV)/bin/pip

# Default Scrapy targets (Override via CLI: make generate PROJECT=my_scraper)
PROJECT ?= sof
SPIDER ?= images
URL ?= "https://www.google.com/search?q=https://images-pw.pixieset.com/site/B8vK3b/RnMmeP/SOF\_1587-b8d3c251-1500.jpg"

all: venv generate

# 1. Provision isolated environment
venv:
	python3 -m venv $(VENV)
	$(PIP) install --upgrade pip
	$(PIP) install scrapy pillow beautifulsoup4 lxml httpx

# 2. Run the Python scaffold generator (non-interactive defaults or CLI overrides)
generate:
	$(PYTHON) scaffold.py --project $(PROJECT) --spider $(SPIDER) --url $(URL)

# 3. Interactive single-URL prompt-driven Scrapy spider generator
prompt:
	$(PYTHON) scaffold.py --interactive

interactive: prompt

# 4. Launch the interactive Akasha Omni-Enumerator (scraper.py)
enumerate:
	$(PYTHON) scraper.py --menu

# 5. Execute the generated crawler
crawl:
	cd $(PROJECT) && $( if [ -x "../$(VENV)/bin/scrapy" ]; then echo "../$(VENV)/bin/scrapy"; else echo "scrapy"; fi ) crawl $(SPIDER) -o output.json

# 6. Execute verification test suite
test:
	python3 -B -m unittest discover -s tests -p "test_*.py"

# 7. Burn it all down
clean:
	rm -rf $(VENV)
	rm -rf $(PROJECT)
	find . -type d -name "__pycache__" -exec rm -rf {} +
