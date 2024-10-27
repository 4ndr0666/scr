#!/usr/bin/env python3

import sys
import urllib.request
import xmltodict
import re
import os
from dateutil.parser import parse
from datetime import datetime

def clean_html(raw_html):
    cleanr = re.compile('<.*?>')
    cleantext = re.sub(cleanr, '', raw_html)
    return cleantext

def get_last_check_time():
    cache_dir = os.path.join(os.path.expanduser('~'), '.cache')
    last_check_file = os.path.join(cache_dir, 'arch_news_last_check')
    if os.path.exists(last_check_file):
        with open(last_check_file, 'r') as f:
            last_check_str = f.read().strip()
            return parse(last_check_str), last_check_file
    else:
        return None, last_check_file

def save_last_check_time(last_check_time):
    cache_dir = os.path.join(os.path.expanduser('~'), '.cache')
    os.makedirs(cache_dir, exist_ok=True)
    last_check_file = os.path.join(cache_dir, 'arch_news_last_check')
    with open(last_check_file, 'w') as f:
        f.write(last_check_time.isoformat())

def upgrade_alerts():
    last_check_time, last_check_file = get_last_check_time()

    url = 'https://www.archlinux.org/feeds/news/'
    with urllib.request.urlopen(url) as response:
        data = response.read()

    arch_news = xmltodict.parse(data)

    exit_code = 0
    latest_pub_date = last_check_time

    for news_post in arch_news['rss']['channel']['item']:
        pub_date = parse(news_post['pubDate']).replace(tzinfo=None)
        if last_check_time is None or pub_date > last_check_time:
            exit_code = 1
            print('~' * int(os.environ.get('COLUMNS', '80')))
            print("\nTITLE: ", news_post['title'], "\n")
            print("DATE: ", news_post['pubDate'], "\n")
            print("DESCRIPTION: ", clean_html(news_post['description']), "\n")

            if latest_pub_date is None or pub_date > latest_pub_date:
                latest_pub_date = pub_date

    if latest_pub_date:
        save_last_check_time(latest_pub_date)

    return exit_code

if __name__ == '__main__':
    sys.exit(upgrade_alerts())
