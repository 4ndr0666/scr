
import scrapy
from scrapy.exceptions import CloseSpider
from urllib.parse import urljoin

class images(scrapy.Spider):
    name = "images"
    allowed_domains = ["cdn.bunnylust.com"]
    start_urls = ["https://cdn.bunnylust.com/app/uploads/2023/06/lana-lane-black-lingerie-cosmid-11.jpg"]

    def parse(self, response):
        if response.status != 200:
            self.logger.warning(f"Failed to retrieve URL: {response.url} with status: {response.status}")
            raise CloseSpider(f"Non-200 status code encountered: {response.status}")

        # Extract image URLs
        image_urls = response.css('img::attr(src)').getall()
        for img_url in image_urls:
            full_img_url = urljoin(response.url, img_url)
            image_name = self.extract_image_name(full_img_url)
            yield {
                'image_urls': [full_img_url],
                'image_name': image_name,
                'page_url': response.url,
            }

        # Extract and follow directory links
        dir_links = response.css('a::attr(href)').re(r'.*/$')
        for link in dir_links:
            full_link = urljoin(response.url, link)
            yield scrapy.Request(full_link, callback=self.parse, errback=self.handle_error)

    def handle_error(self, failure):
        self.logger.error(f"Request failed: {failure.request.url} with error: {failure.value}")

    def extract_image_name(self, url):
        image_name = url.split('/')[-1].split('.')[0]
        return image_name.strip().replace('_', ' ').replace('-', ' ').capitalize()
