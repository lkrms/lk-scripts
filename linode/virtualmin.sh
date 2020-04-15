#!/bin/bash
# <UDF name="NODE_HOSTNAME" label="Hostname" />
# <UDF name="NODE_FQDN" label="FQDN" />
# <UDF name="NODE_TIMEZONE" label="Timezone" default="Australia/Sydney" />
# <UDF name="ADMIN_USERNAME" label="Admin username" default="linac" />

set -euo pipefail

# basics.sh
. <ssinclude StackScriptID="641223">

wget "http://software.virtualmin.com/gpl/scripts/install.sh"
sudo sh install.sh --force --verbose --hostname "$NODE_FQDN"
