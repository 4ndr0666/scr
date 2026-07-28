Here is the formatted and organized `README.md` file based on your notes. The information has been structured logically, grouping the reconnaissance steps, extraction strategies, and execution commands into a cohesive guide.

---

# WordPress Media Enumeration Toolkit

This guide outlines methodologies for enumerating and extracting media from WordPress directories (`wp-content/uploads/`), addressing binary server configurations: **Open Directory** vs. **Forbidden**.

---

## 1. Initial Reconnaissance: REST API Check

First, run `curl -I` on the target domain to determine if the WordPress REST API was left active by inspecting its headers.

```bash
curl -I https://www.mfsport.net

```

Look for the following link header in the response:

> `link: [https://www.mfsport.net/wp-json/](https://www.mfsport.net/wp-json/); rel="[https://api.w.org/](https://api.w.org/)"`

This means the **WordPress REST API is active**. You should attempt to pull the master media list directly from the database first. If the administrator forgot to lock down the `/media` endpoint, the server will hand you every single image URL it has.

---

## 2. Extraction Strategies

Depending on your reconnaissance results, utilize one of the following scenarios to extract the media assets.

### Scenario A: Open API / Open Directory (The Easy Way)

#### The WP-JSON Exploit

Run this quick `curl` command in your terminal. It queries the API for the last 10 media uploads and uses `jq` to parse out just the raw URLs:

```bash
curl -s "https://www.mfsport.net/wp-json/wp/v2/media?per_page=10" | jq -r '.[].source_url'

```

* **If it spits out a list of `.jpg` URLs:** You hit the jackpot. You can iterate through `?page=1`, `?page=2`, etc., and dump the entire server's media library in seconds without guessing a single filename. Proceed to the **Recursive JSON Parser** below.
* **If it returns an error** (e.g., `rest_forbidden` or empty output): The admin locked the media endpoint. Skip to **Scenario B**.

#### The Recursive JSON Parser (Weaponized API Scraper)

> This allows you to weaponize the spider to consume the open REST API, paginate through it at the maximum allowed limit (100 items per page), extract the `source_url`, delegate to `gallery-dl`, and automatically jump to the next page until the server runs out of files.

Run this command to build the recursive parser:

```bash
cat << 'EOF' > spiders/akasha_enum.py
import scrapy
import subprocess
import json
from urllib.parse import urlparse, parse_qs, urlencode, urlunparse

class AkashaSpider(scrapy.Spider):
    name = "akasha_enum"
    
    # Target the API directly, asking for the max 100 items per page
    start_urls = ["https://www.mfsport.net/wp-json/wp/v2/media?per_page=100&page=1"]

    def parse(self, response):
        # 1. Decode the JSON payload
        try:
            data = json.loads(response.text)
        except json.JSONDecodeError:
            self.logger.error("Failed to decode JSON. Server might have blocked the request.")
            return

        # 2. Check if we hit the end of the database
        if isinstance(data, dict) and data.get("code") in ["rest_post_invalid_page_number", "rest_forbidden"]:
            self.logger.info("[*] Reached the end of the media library or hit a block.")
            return
        
        if not data:
            self.logger.info("[*] Empty page received. Sequence complete.")
            return

        # 3. Extract all URLs and delegate to gallery-dl
        for item in data:
            image_url = item.get("source_url")
            if image_url:
                self.logger.info(f"VALID: {image_url} - Delegating to gallery-dl...")
                subprocess.run(["gallery-dl", image_url], stdout=subprocess.DEVNULL)
                yield {"url": image_url, "downloaded": True}

        # 4. Automatically reconstruct the URL to pull the next page
        parsed_url = urlparse(response.url)
        qs = parse_qs(parsed_url.query)
        current_page = int(qs.get('page', ['1'])[0])
        next_page = current_page + 1
        
        qs['page'] = [str(next_page)]
        new_query = urlencode(qs, doseq=True)
        next_page_url = urlunparse(parsed_url._replace(query=new_query))
        
        # 5. Queue the next page recursively
        yield scrapy.Request(next_page_url, callback=self.parse)
EOF

```

#### Open Directory Scraping

If the REST API is locked, but directory indexing is enabled on the server, tell Scrapy to hit the directory root, scrape every `href` link ending in `.jpg`, and download it with this config:

```python
# spiders/akasha_enum.py
import scrapy
import subprocess

class AkashaSpider(scrapy.Spider):
    name = "akasha_enum"

    # Point directly at the directory roots
    start_urls = [
        "https://www.mfsport.net/wp-content/uploads/2019/09/",
        "https://www.mfsport.net/wp-content/uploads/2021/11/"
    ]

    def parse(self, response):
        if response.status == 200:
            # Extract all links that end in .jpg from the directory index
            jpg_links = response.css('a::attr(href)').re(r'.*\.jpg$')
            
            for link in jpg_links:
                full_url = response.urljoin(link)
                self.logger.info(f"DISCOVERED: {full_url} - Delegating to gallery-dl...")
                subprocess.run(["gallery-dl", full_url], stdout=subprocess.DEVNULL)
                yield {"url": full_url, "downloaded": True}
        else:
            self.logger.error(f"Directory listing denied: HTTP {response.status}")

```

---

### Scenario B: The Full Brute-Force Matrix

If the API is locked and directories are forbidden, we resort to math. Assuming the target camera uses a 4-digit sequential pattern, this spider will silently grind through `0000` to `9999` for the required directory patterns.

*Note: With `LOG_LEVEL = 'INFO'` configured in `settings.py`, the spider will not spam the console with 404 errors. It will only print a line when it successfully extracts a valid asset.*

Run this to overwrite your spider with the brute-force configuration:

```bash
cat << 'EOF' > spiders/akasha_enum.py
import scrapy
import subprocess

class AkashaSpider(scrapy.Spider):
    name = "akasha_enum"

    def start_requests(self):
        base_2019 = "https://www.mfsport.net/wp-content/uploads/2019/09"
        base_2021 = "https://www.mfsport.net/wp-content/uploads/2021/11"

        # Enumerate the full 0000-9999 camera numbering spectrum
        for i in range(0, 10000):
            padded_num = f"{i:04d}" # Formats '1' to '0001'
            
            # Target Vector 1: 2019 format (DSC4844.jpg)
            yield scrapy.Request(
                url=f"{base_2019}/DSC{padded_num}.jpg", 
                callback=self.parse, 
                dont_filter=True
            )
            
            # Target Vector 2: 2021 format (DSC_1715.jpg)
            yield scrapy.Request(
                url=f"{base_2021}/DSC_{padded_num}.jpg", 
                callback=self.parse, 
                dont_filter=True
            )

    def parse(self, response):
        # We only catch valid HTTP 200 responses. Everything else is ignored by Scrapy.
        if response.status == 200:
            self.logger.info(f"VALID: {response.url} - Delegating to gallery-dl...")
            subprocess.run(["gallery-dl", response.url], stdout=subprocess.DEVNULL)
            yield {"url": response.url, "downloaded": True}
EOF

```

---

## 3. Execution

Once your `akasha_enum.py` spider is built using one of the strategies above, clear out any old JSON files and launch the crawler. You can minimize the terminal and let it run through the VPN tunnel in the background:

```bash
rm -f results.json && scrapy crawl akasha_enum -o results.json

```
