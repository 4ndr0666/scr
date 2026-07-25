#!/usr/bin/env python3
import os
import subprocess
import argparse
import textwrap

def validate_and_create_dir(path):
    if not os.path.exists(path):
        os.makedirs(path)
    return path

def define_spider(spider_name, project_name, start_url):
    spiders_dir = validate_and_create_dir(os.path.join(project_name, project_name, 'spiders'))
    spider_file_path = os.path.join(spiders_dir, f'{spider_name.lower()}.py')
    
    # Safely extract domain
    allowed_domain = start_url.split('/')[2] if "://" in start_url else start_url.split('/')[0]

    spider_code = f'''\
    import scrapy
    from scrapy.exceptions import CloseSpider
    from {project_name}.items import {project_name.capitalize()}Item

    class {spider_name}Spider(scrapy.Spider):
        name = "{spider_name.lower()}"
        allowed_domains = ["{allowed_domain}"]
        start_urls = ["{start_url}"]

        def parse(self, response):
            if response.status != 200:
                self.logger.warning(f"Failed to retrieve URL: {{response.url}} (HTTP {{response.status}})")
                raise CloseSpider(f"Non-200 status code encountered: {{response.status}}")

            image_url = response.url
            image_name = self.extract_image_name(image_url)

            # Yielding the actual Item class you generated
            item = {project_name.capitalize()}Item()
            item['image_urls'] = [image_url]
            item['image_name'] = image_name
            item['page_url'] = response.url
            yield item

            # Example pagination/iteration logic
            try:
                current_num = self.extract_image_number(image_url)
                next_image_url = image_url.replace(f'{{current_num}}', f'{{current_num + 1}}')
                yield scrapy.Request(next_image_url, callback=self.parse, errback=self.handle_error)
            except Exception as e:
                self.logger.debug(f"Could not iterate URL: {{e}}")

        def handle_error(self, failure):
            self.logger.error(f"Request failed: {{failure.request.url}}")

        def extract_image_name(self, url):
            image_name = url.split('/')[-1].split('.')[0]
            return image_name.strip().replace('_', ' ').replace('-', ' ').capitalize()

        def extract_image_number(self, url):
            # Regex or robust extraction is recommended here for production
            try:
                return int(''.join(filter(str.isdigit, url.split('/')[-1])))
            except ValueError:
                return 0
    '''
    with open(spider_file_path, 'w') as f:
        f.write(textwrap.dedent(spider_code))

def configure_settings(project_name):
    settings_file_path = os.path.join(project_name, project_name, 'settings.py')
    
    settings_append = f'''
# --- Custom Anti-Ban & Stability Settings ---
# Replaces default async DNS with standard threaded resolver (VPN/Arch safe)
DNS_RESOLVER = 'scrapy.resolver.CachingThreadedResolver'

DOWNLOAD_DELAY = 1.0
CONCURRENT_REQUESTS = 2
CONCURRENT_REQUESTS_PER_DOMAIN = 2

USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36'
LOG_LEVEL = 'INFO'
HTTPCACHE_ENABLED = True
AUTOTHROTTLE_ENABLED = True

# --- Pipeline Configuration ---
IMAGES_STORE = 'images'
ITEM_PIPELINES = {{
    'scrapy.pipelines.images.ImagesPipeline': 1,
    '{project_name}.pipelines.{project_name.capitalize()}Pipeline': 300,
}}
'''
    with open(settings_file_path, 'a') as f:
        f.write(settings_append)

def update_items_py(project_name):
    items_code = f'''\
    import scrapy

    class {project_name.capitalize()}Item(scrapy.Item):
        image_urls = scrapy.Field()
        images = scrapy.Field()
        image_name = scrapy.Field()
        page_url = scrapy.Field()
        timestamp = scrapy.Field()
    '''
    with open(os.path.join(project_name, project_name, 'items.py'), 'w') as f:
        f.write(textwrap.dedent(items_code))

def update_middlewares_py(project_name):
    # Standard boilerplate can remain mostly unchanged, but skipped here for brevity 
    # to focus on the critical network paths. (You can paste your original middleware block here).
    pass 

def update_pipelines_py(project_name):
    pipelines_code = f'''\
    import os
    from scrapy.pipelines.images import ImagesPipeline
    from scrapy.exceptions import DropItem
    from scrapy import Request

    class {project_name.capitalize()}Pipeline:
        def process_item(self, item, spider):
            if not item.get('image_urls') or not item.get('image_name'):
                raise DropItem(f"Missing required fields in {{item}}")
            item['image_name'] = self.clean_image_name(item['image_name'])
            return item

        def clean_image_name(self, name):
            return name.strip().replace(' ', '_').replace('/', '-')

    class {project_name.capitalize()}ImagesPipeline(ImagesPipeline):
        def get_media_requests(self, item, info):
            for image_url in item.get('image_urls', []):
                yield Request(image_url, meta={{'image_name': item.get('image_name')}})

        def file_path(self, request, response=None, info=None, *, item=None):
            image_name = request.meta.get('image_name', 'default_name')
            image_guid = os.path.basename(request.url)
            return f"{{image_name}}/{{image_guid}}"
    '''
    with open(os.path.join(project_name, project_name, 'pipelines.py'), 'w') as f:
        f.write(textwrap.dedent(pipelines_code))

def setup_pyproject_toml(project_name):
    toml_content = f'''\
    [tool.poetry]
    name = "{project_name}"
    version = "0.1.0"
    description = "Automated Scrapy Extraction Matrix"
    authors = ["Ghost <ghost@matrix.local>"]
    
    [tool.poetry.dependencies]
    python = "^3.11"
    scrapy = "^2.11.0"
    pillow = "^10.0.0"
    '''
    with open(os.path.join(project_name, 'pyproject.toml'), 'w') as f:
        f.write(textwrap.dedent(toml_content))

def parse_arguments():
    parser = argparse.ArgumentParser(description="Automate Scrapy Scaffold")
    parser.add_argument("--url", help="Start URL")
    parser.add_argument("--project", help="Project name")
    parser.add_argument("--spider", help="Spider name")
    args = parser.parse_args()

    # Interactive fallback if args are missing
    if not all([args.url, args.project, args.spider]):
        print("Missing CLI arguments. Falling back to interactive mode:")
        args.project = input("Enter project name: ").strip() or "akasha_enum"
        args.spider = input("Enter spider name: ").strip() or "akasha"
        args.url = input("Enter start URL: ").strip() or "https://www.example.com"
        
    return args.project, args.spider, args.url

def main():
    project_name, spider_name, start_url = parse_arguments()
    
    validate_and_create_dir(project_name)
    subprocess.run(["scrapy", "startproject", project_name])
    
    define_spider(spider_name, project_name, start_url)
    configure_settings(project_name)
    update_items_py(project_name)
    update_pipelines_py(project_name)
    setup_pyproject_toml(project_name)
    
    print(f"\n[+] Scaffold complete. Run: cd {project_name} && scrapy crawl {spider_name.lower()}")

if __name__ == "__main__":
    main()
