.PHONY: all venv clean generate crawl

# --- Variables ---
VENV := .venv
PYTHON := $(VENV)/bin/python
PIP := $(VENV)/bin/pip

# Default Scrapy targets (Override via CLI: make generate PROJECT=my_scraper)
PROJECT ?= akasha_enum
SPIDER ?= akasha
URL ?= "https://www.mfsport.net/wp-content/uploads/2021/11/DSC_1715.jpg"

all: venv generate

# 1. Provision isolated environment
venv:
	python3 -m venv $(VENV)
	$(PIP) install --upgrade pip
	$(PIP) install scrapy pillow beautifulsoup4

# 2. Run the Python scaffold generator
generate: venv
	$(PYTHON) scaffold.py --project $(PROJECT) --spider $(SPIDER) --url $(URL)

# 3. Execute the generated crawler
crawl:
	cd $(PROJECT) && ../$(VENV)/bin/scrapy crawl $(SPIDER) -o output.json

# 4. Burn it all down
clean:
	rm -rf $(VENV)
	rm -rf $(PROJECT)
	find . -type d -name "__pycache__" -exec rm -rf {} +
