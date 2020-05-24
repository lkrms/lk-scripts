#!/usr/bin/env python3

from datetime import datetime
from xml.etree import ElementTree as etree

import configparser
import os
import requests
import sys

lk_root_dir = os.path.normpath(
    os.path.dirname(os.path.realpath(__file__)) + "/..")
lk_config_dir = lk_root_dir + "/etc"
lk_cache_dir = lk_root_dir + "/var/cache"

os.makedirs(lk_config_dir, exist_ok=True)
os.makedirs(lk_cache_dir + "/overcast", exist_ok=True)

config_file = lk_config_dir + "/overcast.ini"
cache_file = lk_cache_dir + "/overcast/overcast.opml"

config = configparser.ConfigParser()
config.read_dict({
    'overcast':
    {
        'email': "your@email.com",
        'password': "",
        'opml_last_retrieved': "0"
    }
})

if os.path.exists(config_file):
    config.read(config_file)

try:
    if not config['overcast']['password']:
        raise ValueError("No Overcast password configured")

    now = int(datetime.now().timestamp())

    if not os.path.isfile(cache_file) or now - int(config['overcast']['opml_last_retrieved']) > 3600 * 8:

        print("Logging in...")

        s = requests.Session()
        r = s.post("https://overcast.fm/login", data={
            'email': config['overcast']['email'],
            'password': config['overcast']['password']
        })

        if r.status_code != 200:
            raise RuntimeError("Authentication failed")

        print("Authentication succeeded")

        print("Downloading OPML...")
        r = s.get("https://overcast.fm/account/export_opml/extended")

        if r.status_code != 200:
            raise RuntimeError("Download failed")

        if os.path.exists(cache_file):
            backup_file = cache_file.replace(".opml", "-" + str(now) + ".opml")
            i = 1
            while os.path.exists(backup_file):
                i += 1
                backup_file = cache_file.replace(
                    ".opml", "-" + str(now) + "-" + str(i) + ".opml")

            os.rename(cache_file, backup_file)

        with open(cache_file, 'w') as fp:
            fp.write(r.text)

        config['overcast']['opml_last_retrieved'] = str(now)

        opml = r.text

    else:

        print("Using cached OPML file")

        with open(cache_file, 'r') as fp:
            opml = fp.read()

finally:

    with open(config_file, 'w') as fp:
        config.write(fp)

tree = etree.fromstring(opml)

podcasts = tree.findall(".//*[@type='rss']")

for podcast in podcasts:
    p_title = podcast.attrib['title']

    for episode in list(podcast):
        e_title = episode.attrib['title']
