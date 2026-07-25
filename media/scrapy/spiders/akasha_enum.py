import scrapy
import subprocess

BASE_2019 = "https://www.mfsport.net/wp-content/uploads/2019/09"
BASE_2021 = "https://www.mfsport.net/wp-content/uploads/2021/11"

class AkashaSpider(scrapy.Spider):
    name = "akasha_enum"

    # Tightened ranges to eliminate the 404 buffer waste
    start_urls = (
        [f"{BASE_2019}/DSC{i}.jpg" for i in range(4844, 4899)] +
        [f"{BASE_2021}/DSC_{i}.jpg" for i in range(1715, 1878)] +
        [f"{BASE_2021}/2110123-Ekipe-Orizzonte-NC-Milano-30.jpg"]
    )

    def parse(self, response):
        if response.status == 200:
            self.logger.info(f"VALID: {response.url} - Delegating to gallery-dl...")
            subprocess.run(["gallery-dl", response.url], stdout=subprocess.DEVNULL)
            yield {"url": response.url, "downloaded": True}
