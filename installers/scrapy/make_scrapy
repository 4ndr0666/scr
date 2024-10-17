import os
import subprocess
import sys

def prompt_for_variables():
    """Prompt the user for necessary project variables with validation."""
    project_name = input("Enter the Scrapy project name: ").strip()
    if not project_name:
        raise ValueError("Project name cannot be empty.")

    spider_name = input("Enter the spider class name: ").strip()
    if not spider_name:
        raise ValueError("Spider name cannot be empty.")

    start_url = input("Enter the start URL for the spider: ").strip()
    if not start_url.startswith("http"):
        raise ValueError("Invalid URL format. Must start with 'http'.")

    return project_name, spider_name, start_url

def validate_and_create_dir(path):
    """Validate if the directory exists; if not, create it."""
    if not os.path.exists(path):
        os.makedirs(path)
    return path

def install_scrapy():
    """Install Scrapy and required dependencies."""
    subprocess.check_call([sys.executable, "-m", "pip", "install", "scrapy"])

def create_project(project_name):
    """Create a new Scrapy project."""
    validate_and_create_dir(project_name)
    subprocess.run(["scrapy", "startproject", project_name])

def define_spider(spider_name, project_name, start_url):
    """Define a spider using user-provided variables."""
    spiders_dir = validate_and_create_dir(os.path.join(project_name, project_name, 'spiders'))
    spider_file_path = os.path.join(spiders_dir, f'{spider_name.lower()}.py')
    spider_code = f'''
import scrapy
from scrapy.exceptions import CloseSpider

class {spider_name}(scrapy.Spider):
    name = "{spider_name.lower()}"
    allowed_domains = ["{start_url.split('/')[2]}"]
    start_urls = ["{start_url}"]

    def parse(self, response):
        if response.status != 200:
            self.log(f"Failed to retrieve URL: {{response.url}} with status: {{response.status}}", level=scrapy.log.WARNING)
            raise CloseSpider(f"Non-200 status code encountered: {{response.status}}")

        image_url = response.url
        image_name = self.extract_image_name(image_url)

        yield {{
            'image_urls': [image_url],
            'image_name': image_name,
            'page_url': response.url,
        }}

        current_num = self.extract_image_number(image_url)
        next_num = current_num + 1

        next_image_url = image_url.replace(f'-{{current_num}}-', f'-{{next_num}}-')
        yield scrapy.Request(next_image_url, callback=self.parse, errback=self.handle_error)

    def handle_error(self, failure):
        self.log(f"Request failed with error: {{failure}}", level=scrapy.log.ERROR)

    def extract_image_name(self, url):
        image_name = url.split('/')[-1].split('-')[0]
        return image_name.strip().replace('_', ' ').replace('-', ' ').capitalize()

    def extract_image_number(self, url):
        return int(url.split('-')[-2])
'''
    with open(spider_file_path, 'w') as spider_file:
        spider_file.write(spider_code)

def configure_settings(project_name):
    """Modify settings.py based on user input."""
    settings_file_path = os.path.join(project_name, project_name, 'settings.py')
    with open(settings_file_path, 'a') as settings_file:
        settings_file.write('''
# Custom Settings
ITEM_PIPELINES = {
    'scrapy.pipelines.images.ImagesPipeline': 1,
}
IMAGES_STORE = 'images'
AUTOTHROTTLE_ENABLED = True
HTTPCACHE_ENABLED = True
LOG_LEVEL = 'INFO'
        ''')

def update_items_py(project_name):
    """Update items.py with the necessary item fields."""
    items_code = f'''
import scrapy

class {project_name.capitalize()}Item(scrapy.Item):
    image_urls = scrapy.Field()
    images = scrapy.Field()
    image_name = scrapy.Field()
    page_url = scrapy.Field()
    timestamp = scrapy.Field()
'''
    items_path = os.path.join(project_name, project_name, 'items.py')
    with open(items_path, 'w') as items_file:
        items_file.write(items_code)

def update_middlewares_py(project_name):
    """Update middlewares.py with enhanced middleware functions."""
    middlewares_code = f'''
from scrapy import signals
import random

class {project_name.capitalize()}SpiderMiddleware:
    @classmethod
    def from_crawler(cls, crawler):
        s = cls()
        crawler.signals.connect(s.spider_opened, signal=signals.spider_opened)
        return s

    def process_spider_input(self, response, spider):
        spider.logger.info(f"Processing response from: {{response.url}}")
        return None

    def process_spider_output(self, response, result, spider):
        for i in result:
            yield i

    def spider_opened(self, spider):
        spider.logger.info(f"Spider opened: {{spider.name}}")


class {project_name.capitalize()}DownloaderMiddleware:
    USER_AGENTS = [
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
        "Mozilla/5.0 (X11; Linux x86_64)"
    ]

    @classmethod
    def from_crawler(cls, crawler):
        s = cls()
        crawler.signals.connect(s.spider_opened, signal=signals.spider_opened)
        return s

    def process_request(self, request, spider):
        user_agent = random.choice(self.USER_AGENTS)
        request.headers['User-Agent'] = user_agent
        return None

    def spider_opened(self, spider):
        spider.logger.info(f"Spider opened: {{spider.name}}")
'''
    middlewares_path = os.path.join(project_name, project_name, 'middlewares.py')
    with open(middlewares_path, 'w') as middlewares_file:
        middlewares_file.write(middlewares_code)

def update_pipelines_py(project_name):
    """Update pipelines.py with enhanced pipeline functions."""
    pipelines_code = f'''
from scrapy.pipelines.images import ImagesPipeline
from scrapy.exceptions import DropItem
from scrapy import Request

class {project_name.capitalize()}Pipeline:
    def process_item(self, item, spider):
        if not item.get('image_urls') or not item.get('image_name'):
            raise DropItem(f"Missing required fields in {{item}}")
        item['image_name'] = self.clean_image_name(item['image_name'])
        spider.logger.info(f"Processed item: {{item}}")
        return item

    def clean_image_name(self, name):
        return name.strip().replace(' ', '_').replace('/', '-')

class {project_name.capitalize()}ImagesPipeline(ImagesPipeline):
    def get_media_requests(self, item, info):
        for image_url in item['image_urls']:
            yield Request(image_url, meta={'image_name': item.get('image_name')})

    def file_path(self, request, response=None, info=None, *, item=None):
        image_name = request.meta.get('image_name', 'default_name')
        image_guid = os.path.basename(request.url)
        filename = f"{image_name}/{image_guid}"
        return filename

    def item_completed(self, results, item, info):
        if not all([x[0] for x in results]):
            raise DropItem(f"Failed to download images for {{item}}")
        return item
'''
    pipelines_path = os.path.join(project_name, project_name, 'pipelines.py')
    with open(pipelines_path, 'w') as pipelines_file:
        pipelines_file.write(pipelines_code)

def review_scrapy_cfg(project_name):
    """Review and enhance scrapy.cfg for proper project setup."""
    cfg_code = f'''
[settings]
default = {project_name}.settings

[deploy]
project = {project_name}
loglevel = INFO
output_format = jsonlines
output_dir = output
'''
    cfg_path = os.path.join(project_name, 'scrapy.cfg')
    with open(cfg_path, 'w') as cfg_file:
        cfg_file.write(cfg_code)

def setup_pyproject_toml(project_name):
    """Setup pyproject.toml with the necessary dependencies."""
    toml_content = f'''
[tool.poetry]
name = "{project_name}"
version = "0.1.0"
description = ""
authors = ["Your Name <you@example.com>"]
readme = "README.md"

[tool.poetry.dependencies]
python = "^3.12"
scrapy = "^2.7.0"
beautifulsoup4 = "^4.12.3"
pillow = "^10.4.0"

[build-system]
requires = ["poetry-core"]
build-backend = "poetry.core.masonry.api"
'''
    toml_path = os.path.join(project_name, 'pyproject.toml')
    with open(toml_path, 'w') as toml_file:
        toml_file.write(toml_content)

def setup_project():
    """Setup the entire Scrapy project by prompting for variables and calling setup functions in sequence."""
    project_name, spider_name, start_url = prompt_for_variables()
    
    # Install Scrapy and create the project
    install_scrapy()
    create_project(project_name)
    
    # Dynamically define the spider and its associated components
    define_spider(spider_name, project_name, start_url)
    configure_settings(project_name)
    update_items_py(project_name)
    update_middlewares_py(project_name)
    update_pipelines_py(project_name)
    review_scrapy_cfg(project_name)
    setup_pyproject_toml(project_name)
    
    print(f"Project {project_name} setup complete.")

if __name__ == "__main__":
    setup_project()
