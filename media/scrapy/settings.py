BOT_NAME = 'akasha_enum'
SPIDER_MODULES = ['spiders']
NEWSPIDER_MODULE = 'spiders'

# Stability & Throttling (1 request per second)
DOWNLOAD_DELAY = 1.0
CONCURRENT_REQUESTS = 2
CONCURRENT_REQUESTS_PER_DOMAIN = 2

USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36'
