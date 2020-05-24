#!/usr/bin/env python

# from https://community.letsencrypt.org/t/view-existing-email-certbot-or-letsencrypt-org/109851/4

from acme.client import ClientV2
from acme.client import ClientNetwork
from acme import messages
import josepy as jose
from glob import glob

with open(glob('/etc/letsencrypt/accounts/acme-v02.api.letsencrypt.org/directory/*/private_key.json')[0], 'rb') as f:
    key = jose.JWK.json_loads(f.read())

with open(glob('/etc/letsencrypt/accounts/acme-v02.api.letsencrypt.org/directory/*/regr.json')[0], 'r') as f:
    regr = messages.RegistrationResource.json_loads(f.read())

net = ClientNetwork(key)
directory = messages.Directory.from_json(
    net.get("https://acme-v02.api.letsencrypt.org/directory").json())
client = ClientV2(directory, net)

client.net.account = regr
resp = client._post(regr.uri, None)

print(resp.json()['contact'])
