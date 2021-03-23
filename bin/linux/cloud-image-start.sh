#!/bin/bash
# shellcheck disable=SC1091,SC2015,SC2016

include=linux,validate . lk-bash-load.sh || exit

IMAGE=ubuntu-18.04-minimal
VM_PACKAGES=
VM_FILESYSTEM_MAPS=
VM_MEMORY=4096
VM_CPUS=2
VM_DISK_SIZE=80G
VM_IPV4_ADDRESS=
VM_MAC_ADDRESS=$(printf '52:54:00:%02x:%02x:%02x' \
    $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)))
REFRESH_CLOUDIMG=
FORWARD_XML=()
ISOLATE=
ALLOW_HOST_XML=
ALLOW_HOST_NET_XML=
ALLOW_HOSTS_XML=()
ALLOW_URL_XML=()
STACKSCRIPT=
METADATA=()
METADATA_URLS=()
FORCE_DELETE=

# shellcheck disable=SC2034
LK_USAGE="\
Usage: ${0##*/} [OPTIONS] VM_NAME

Boot a new QEMU/KVM virtual machine from the current release of a cloud-init
based image.

Options:
  -i, --image=IMAGE             boot from IMAGE (default: $IMAGE)
  -r, --refresh-image           download latest IMAGE if cached version is
                                out-of-date
  -p, --packages=PACKAGE,...    install each PACKAGE in guest after booting
  -f, --fs-maps=PATHS|...       export HOST_PATH to guest as GUEST_PATH for
                                each HOST_PATH,GUEST_PATH in PATHS
  -P, --preset=PRESET           use PRESET to configure -m, -c, -s
  -m, --memory=SIZE             allocate SIZE memory in MiB (default: $VM_MEMORY)
  -c, --cpus=COUNT              allocate COUNT virtual CPUs (default: $VM_CPUS)
  -s, --disk-size=SIZE          resize IMAGE to SIZE in GiB (default: $VM_DISK_SIZE)
  -n, --network=NETWORK         connect guest to libvirt network NETWORK, or
                                IFNAME if bridge=IFNAME specified
  -I, --ip-address=CIDR         use CIDR to configure static IP in guest
  -R, --forward=PORTS|...       add custom metadata to forward each
                                PROTO:<HOST-PORT[:GUEST-PORT],...> in PORTS to
                                guest (--ip-address required)
  -O, --isolate                 add custom metadata to block outgoing traffic
                                from guest (--ip-address required)
  -M, --mac=52:54:00:xx:xx:xx   set MAC address of guest network interface
                                (default: <random>)
  -S, --stackscript=SCRIPT      use cloud-init to run SCRIPT in guest after
                                booting (see below)
  -x, --metadata=URL,KEY,XML    add custom metadata XML
  -u, --session                 launch guest as user instead of system
  -y, --yes                     do not prompt for input
  -F, --force                   delete existing guest VM_NAME without
                                prompting (implies -y)

If --isolate is set:
  -g, --allow-gateway           allow traffic to host system
  -l, --allow-gateway-lan       allow traffic to host system's default LAN
  -h, --allow-host=HOST,...     allow traffic to each HOST (name, IP or CIDR)
  -U, --allow-url=URL,FILTER    allow traffic to each host returned by
                                passing JSON from URL through \`jq -r FILTER\`

Supported images:
  ubuntu-20.04      ubuntu-20.04-minimal
  ubuntu-18.04      ubuntu-18.04-minimal
  ubuntu-16.04      ubuntu-16.04-minimal
  ubuntu-14.04
  ubuntu-12.04

Presets:
  linode16gb    (6 CPUs, 16GiB memory, 320G storage)
  linode8gb     (4 CPUs,  8GiB memory, 160G storage)
  linode4gb     (2 CPUs,  4GiB memory,  80G storage)
  linode2gb     (1 CPUs,  2GiB memory,  50G storage)
  linode1gb     (1 CPUs,  1GiB memory,  25G storage)

If --forward or --isolate are set, custom metadata similar to the following
is added to the domain XML. It only takes effect if a libvirt hook applies the
relevant firewall changes.

    <lk:lk xmlns:lk=\"http://linacreative.com/xmlns/libvirt/domain/1.0\">
      <lk:ip>
        <lk:address>192.168.122.10</lk:address>
        <lk:forward>
          <lk:protocol>tcp</lk:protocol>
          <lk:port>80</lk:port>
          <lk:port>443</lk:port>
          <lk:from-host>2210</lk:from-host>
          <lk:to-guest>22</lk:to-guest>
        </lk:forward>
        <lk:isolate>
          <lk:allow>
            <lk:gateway />
            <lk:host>10.1.1.1</lk:host>
            <lk:from-url>
              <lk:url>https://api.github.com/meta</lk:url>
              <lk:filter>.web[],.api[],.git[]</lk:filter>
            </lk:from-url>
          </lk:allow>
        </lk:isolate>
      </lk:ip>
    </lk:lk>

StackScript notes:
- The user is prompted for any UDF tags found in the script
- cloud-init is configured to create a Linode-like environment, and the entire
  script is added to the runcmd module
- The --packages option is ignored"

lk_getopt "i:rp:f:P:m:c:s:n:I:R:OM:S:x:uyFglh:U:" \
    "image:,refresh-image,packages:,fs-maps:,preset:,memory:,\
cpus:,disk-size:,network:,ip-address:,forward:,isolate,mac:,stackscript:,\
metadata:,session,force,allow-gateway,allow-gateway-lan,allow-host:,allow-url:"
eval "set -- $LK_GETOPT"

UBUNTU_HOST=${LK_UBUNTU_CLOUDIMG_HOST:-cloud-images.ubuntu.com}

CLOUDIMG_ROOT=${LK_CLOUDIMG_ROOT:-/var/lib/libvirt/images}
VM_POOL_ROOT=$CLOUDIMG_ROOT
VM_NETWORK_DEFAULT=default
LIBVIRT_URI=qemu:///system
LK_SUDO=1
XMLNS=http://linacreative.com/xmlns/libvirt/domain/1.0

eval "$(lk_get_regex HOST_OPT_PREFIX_REGEX URI_REGEX_REQ_SCHEME_HOST)"

while :; do
    OPT=$1
    shift
    case "$OPT" in
    -i | --image)
        IMAGE=$1
        ;;
    -r | --refresh-image)
        REFRESH_CLOUDIMG=yes
        continue
        ;;
    -p | --packages)
        [ -n "$STACKSCRIPT" ] ||
            VM_PACKAGES=$1
        ;;
    -f | --fs-maps)
        VM_FILESYSTEM_MAPS=$1
        ;;
    -P | --preset)
        case "$1" in
        linode1gb)
            VM_CPUS=1
            VM_MEMORY=1024
            VM_DISK_SIZE=25G
            ;;
        linode2gb)
            VM_CPUS=1
            VM_MEMORY=2048
            VM_DISK_SIZE=50G
            ;;
        linode4gb)
            VM_CPUS=2
            VM_MEMORY=4096
            VM_DISK_SIZE=80G
            ;;
        linode8gb)
            VM_CPUS=4
            VM_MEMORY=8192
            VM_DISK_SIZE=160G
            ;;
        linode16gb)
            VM_CPUS=6
            VM_MEMORY=16384
            VM_DISK_SIZE=320G
            ;;
        *)
            lk_warn "invalid preset: $1"
            lk_usage
            ;;
        esac
        ;;
    -m | --memory)
        VM_MEMORY=$1
        ;;
    -c | --cpus)
        VM_CPUS=$1
        ;;
    -s | --disk-size)
        VM_DISK_SIZE=$1
        ;;
    -n | --network)
        VM_NETWORK=$1
        ;;
    -I | --ip-address)
        VM_IPV4_ADDRESS=$1
        ;;
    -R | --forward)
        REGEX='(tcp|udp)(:[0-9]+){1,2}(,[0-9]+(:[0-9]+)?)*'
        [[ $1 =~ ^$REGEX(\|$REGEX)*$ ]] ||
            lk_warn "invalid ports" || lk_usage
        IFS="|"
        PORTS=($1)
        unset IFS
        REGEX='((tcp|udp):)?([0-9]+)(:([0-9]+))?(,(.*))?'
        for FORWARD in "${PORTS[@]}"; do
            _XML=()
            while [[ $FORWARD =~ ^$REGEX ]]; do
                PROTOCOL=${BASH_REMATCH[2]}
                FROM_HOST=${BASH_REMATCH[3]}
                TO_GUEST=${BASH_REMATCH[5]}
                FORWARD=${BASH_REMATCH[7]}
                [ -z "$PROTOCOL" ] ||
                    _XML[${#_XML[@]}]="<protocol>$PROTOCOL</protocol>"
                [ -z "$TO_GUEST" ] &&
                    _XML[${#_XML[@]}]="<port>$FROM_HOST</port>" ||
                    _XML+=("<from-host>$FROM_HOST</from-host>"
                        "<to-guest>$TO_GUEST</to-guest>")
            done
            XML=$(lk_echo_array _XML)
            XML="<forward>
  ${XML//$'\n'/$'\n'  }
</forward>"
            FORWARD_XML[${#FORWARD_XML[@]}]=$XML
        done
        ;;
    -O | --isolate)
        ISOLATE=1
        continue
        ;;
    -M | --mac)
        VM_MAC_ADDRESS=$1
        ;;
    -S | --stackscript)
        [ -f "$1" ] ||
            lk_warn "invalid StackScript: $1" || lk_usage
        STACKSCRIPT=$1
        VM_PACKAGES=
        ;;
    -x | --metadata)
        IFS=, read -r -d '' URL KEY XML < <(printf '%s\0' "$1") &&
            [ -n "${XML:+1}" ] ||
            lk_warn "invalid metadata: $1" || lk_usage
        [ "$URL" != "$XMLNS" ] ||
            lk_warn "metadata URL not allowed: $URL" || lk_usage
        ! lk_in_array "$URL" METADATA_URLS ||
            lk_warn "metadata URL not unique: $URL"
        for i in URL KEY XML; do
            METADATA[${#METADATA[@]}]=${!i}
        done
        METADATA_URLS[${#METADATA_URLS[@]}]=$URL
        unset IFS
        ;;
    -u | --session)
        VM_POOL_ROOT=${LK_CLOUDIMG_SESSION_ROOT:-$HOME/.local/share/libvirt/images}
        VM_NETWORK_DEFAULT=bridge=virbr0
        LIBVIRT_URI=qemu:///session
        unset LK_SUDO
        continue
        ;;
    -y | --yes)
        LK_NO_INPUT=1
        continue
        ;;
    -F | --force)
        FORCE_DELETE=1
        LK_NO_INPUT=1
        continue
        ;;
    -g | --allow-gateway)
        ALLOW_HOST_XML="<gateway />"
        continue
        ;;
    -l | --allow-gateway-lan)
        ALLOW_HOST_NET_XML="<gateway-lan />"
        continue
        ;;
    -h | --allow-host)
        IFS=","
        for HOST in $1; do
            unset IFS
            [[ $HOST =~ $HOST_OPT_PREFIX_REGEX ]] ||
                lk_warn "invalid host: $HOST" || lk_usage
            ALLOW_HOSTS_XML[${#ALLOW_HOSTS_XML[@]}]="<host>$HOST</host>"
        done
        ;;
    -U | --allow-url)
        while IFS=, read -r -d '' URL FILTER; do
            [[ $URL =~ $URI_REGEX_REQ_SCHEME_HOST ]] ||
                lk_warn "invalid URL: $URL" || lk_usage
            ALLOW_URL_XML[${#ALLOW_URL_XML[@]}]="\
<from-url>
  <url>$URL</url>
  <filter>${FILTER:-.}</filter>
</from-url>"
        done < <(IFS="|" && printf '%s\0' $1)
        ;;
    --)
        break
        ;;
    esac
    shift
done

XML=
[ ${ISOLATE:-0} -eq 0 ] || {
    XML=$(
        [ -z "$ALLOW_HOST_XML" ] || echo "$ALLOW_HOST_XML"
        [ -z "$ALLOW_HOST_NET_XML" ] || echo "$ALLOW_HOST_NET_XML"
        lk_echo_array ALLOW_HOSTS_XML
        lk_echo_array ALLOW_URL_XML
    )
    [ -z "${XML:+1}" ] || XML="<allow>
  ${XML//$'\n'/$'\n'  }
</allow>"
    [ -z "${XML:+1}" ] &&
        XML="<isolate />" ||
        XML="<isolate>
  ${XML//$'\n'/$'\n'  }
</isolate>"
}
XML=$(
    lk_echo_array FORWARD_XML
    echo "$XML"
)
[ -z ${XML:+1} ] || {
    [ -n "$VM_IPV4_ADDRESS" ] ||
        lk_warn "--ip-address required with --forward and --isolate" ||
        lk_usage
    XML="<lk>
  <ip>
    <address>$VM_IPV4_ADDRESS</address>
    ${XML//$'\n'/$'\n'    }
  </ip>
</lk>"
    METADATA+=("$XMLNS" lk "$XML")
    METADATA_URLS[${#METADATA_URLS[@]}]=$XMLNS
}

VM_NETWORK=${VM_NETWORK:-$VM_NETWORK_DEFAULT}

VM_HOSTNAME="${1:-}"
[ -n "$VM_HOSTNAME" ] || lk_usage

SHA_KEYRING=/usr/share/keyrings/ubuntu-cloudimage-keyring.gpg
case "$IMAGE" in
*20.04*minimal)
    IMAGE_NAME=ubuntu-20.04-minimal
    IMAGE_URL=http://$UBUNTU_HOST/minimal/releases/focal/release/ubuntu-20.04-minimal-cloudimg-amd64.img
    SHA_URLS=(
        "https://cloud-images.ubuntu.com/minimal/releases/focal/release/SHA256SUMS.gpg"
    )
    OS_VARIANT=ubuntu20.04
    ;;
*20.04*)
    IMAGE_NAME=ubuntu-20.04
    IMAGE_URL=http://$UBUNTU_HOST/focal/current/focal-server-cloudimg-amd64-disk-kvm.img
    SHA_URLS=(
        "https://cloud-images.ubuntu.com/focal/current/SHA256SUMS.gpg"
        "https://cloud-images.ubuntu.com/focal/current/SHA256SUMS"
    )
    OS_VARIANT=ubuntu20.04
    ;;
*18.04*minimal)
    IMAGE_NAME=ubuntu-18.04-minimal
    IMAGE_URL=http://$UBUNTU_HOST/minimal/releases/bionic/release/ubuntu-18.04-minimal-cloudimg-amd64.img
    SHA_URLS=(
        "https://cloud-images.ubuntu.com/minimal/releases/bionic/release/SHA256SUMS.gpg"
    )
    OS_VARIANT=ubuntu18.04
    ;;
*18.04*)
    IMAGE_NAME=ubuntu-18.04
    IMAGE_URL=http://$UBUNTU_HOST/bionic/current/bionic-server-cloudimg-amd64.img
    SHA_URLS=(
        "https://cloud-images.ubuntu.com/bionic/current/SHA256SUMS.gpg"
        "https://cloud-images.ubuntu.com/bionic/current/SHA256SUMS"
    )
    OS_VARIANT=ubuntu18.04
    ;;
*16.04*minimal)
    IMAGE_NAME=ubuntu-16.04-minimal
    IMAGE_URL=http://$UBUNTU_HOST/minimal/releases/xenial/release/ubuntu-16.04-minimal-cloudimg-amd64-disk1.img
    SHA_URLS=(
        "https://cloud-images.ubuntu.com/minimal/releases/xenial/release/SHA256SUMS.gpg"
    )
    OS_VARIANT=ubuntu16.04
    ;;
*16.04*)
    IMAGE_NAME=ubuntu-16.04
    IMAGE_URL=http://$UBUNTU_HOST/xenial/current/xenial-server-cloudimg-amd64-disk1.img
    SHA_URLS=(
        "https://cloud-images.ubuntu.com/xenial/current/SHA256SUMS.gpg"
        "https://cloud-images.ubuntu.com/xenial/current/SHA256SUMS"
    )
    OS_VARIANT=ubuntu16.04
    ;;
*14.04*)
    IMAGE_NAME=ubuntu-14.04
    IMAGE_URL=http://$UBUNTU_HOST/trusty/current/trusty-server-cloudimg-amd64-disk1.img
    SHA_URLS=(
        "https://cloud-images.ubuntu.com/trusty/current/SHA256SUMS.gpg"
        "https://cloud-images.ubuntu.com/trusty/current/SHA256SUMS"
    )
    OS_VARIANT=ubuntu14.04
    ;;
*12.04*)
    IMAGE_NAME=ubuntu-12.04
    IMAGE_URL=http://$UBUNTU_HOST/precise/current/precise-server-cloudimg-amd64-disk1.img
    SHA_URLS=(
        "https://cloud-images.ubuntu.com/precise/current/SHA256SUMS.gpg"
        "https://cloud-images.ubuntu.com/precise/current/SHA256SUMS"
    )
    OS_VARIANT=ubuntu12.04
    ;;
*)
    lk_warn "invalid cloud image: $IMAGE"
    lk_usage
    ;;
esac

if [ -n "$STACKSCRIPT" ]; then
    lk_console_log "Processing StackScript"
    SS_TAGS=()
    lk_mapfile SS_TAGS <(grep -Eo \
        "<(lk:)?[uU][dD][fF]($S+[a-zA-Z]+=\"[^\"]*\")*$S*/>" \
        "$STACKSCRIPT")
    SS_FIELDS=()
    for SS_TAG in ${SS_TAGS[@]+"${SS_TAGS[@]}"}; do
        SS_ATTRIBS=()
        lk_mapfile SS_ATTRIBS <(grep -Eo "[a-z]+=\"[^\"]*\"" <<<"$SS_TAG")
        unset NAME LABEL DEFAULT SELECT_OPTIONS SELECT_TEXT VALIDATE_COMMAND
        LK_REQUIRED=1
        REQUIRED_TEXT=required
        for SS_ATTRIB in ${SS_ATTRIBS[@]+"${SS_ATTRIBS[@]}"}; do
            [[ $SS_ATTRIB =~ ^([a-z]+)=\"([^\"]*)\"$ ]]
            case "${BASH_REMATCH[1]}" in
            name)
                NAME=${BASH_REMATCH[2]}
                ;;
            label)
                LABEL=${BASH_REMATCH[2]}
                ;;
            default)
                DEFAULT=${BASH_REMATCH[2]}
                unset LK_REQUIRED
                REQUIRED_TEXT=optional
                ;;
            oneof | manyof)
                # shellcheck disable=SC2206
                SELECT_OPTIONS=(${BASH_REMATCH[2]//,/ })
                if [ "${BASH_REMATCH[1]}" = oneof ]; then
                    SELECT_TEXT="Value must be one of the following"
                    VALIDATE_COMMAND=(
                        lk_validate_one_of VALUE "${SELECT_OPTIONS[@]}")
                else
                    SELECT_TEXT="Value can be any number of the following (comma-delimited)"
                    VALIDATE_COMMAND=(
                        lk_validate_many_of VALUE "${SELECT_OPTIONS[@]}")
                fi
                ;;
            esac
        done
        ! lk_is_true LK_REQUIRED ||
            [ -n "${VALIDATE_COMMAND+1}" ] ||
            VALIDATE_COMMAND=(lk_validate_not_null VALUE)
        lk_console_item \
            "Checking field $((${#SS_FIELDS[@]} + 1)) of ${#SS_TAGS[@]}:" \
            "$NAME"
        [ -z "${SELECT_TEXT:-}" ] ||
            lk_echo_array SELECT_OPTIONS |
            lk_console_detail_list "$SELECT_TEXT:"
        [ -z "${DEFAULT:-}" ] ||
            lk_console_detail "Default value:" "$DEFAULT"
        SH=$(lk_get_env "$NAME") && eval "$SH" && VALUE=${!NAME} || unset VALUE
        i=0
        while ((++i)); do
            NO_ERROR_DISPLAYED=1
            IS_VALID=1
            [ -z "${VALIDATE_COMMAND+1}" ] ||
                FIELD_ERROR=$(LK_VALIDATE_FIELD_NAME="$NAME" \
                    "${VALIDATE_COMMAND[@]}") ||
                IS_VALID=0
            INITIAL_VALUE=${VALUE-${DEFAULT:-}}
            lk_is_true IS_VALID ||
                ! { lk_no_input || [ "$i" -gt 1 ]; } || {
                lk_console_warning "$FIELD_ERROR"
                unset NO_ERROR_DISPLAYED
            }
            if lk_is_true IS_VALID && { lk_no_input || [ "$i" -gt 1 ]; }; then
                lk_console_detail "Using value:" "$INITIAL_VALUE" "$LK_GREEN"
                break
            else
                VALUE=$(LK_FORCE_INPUT=1 lk_console_read \
                    "$LABEL${NO_ERROR_DISPLAYED+ ($REQUIRED_TEXT)}:" \
                    "" ${INITIAL_VALUE:+-i "$INITIAL_VALUE"})
            fi
        done
        [ "${VALUE:=}" != "${DEFAULT:-}" ] ||
            lk_is_true LK_STACKSCRIPT_EXPORT_DEFAULT ||
            continue
        SS_FIELDS+=("$NAME=$VALUE")
    done
    STACKSCRIPT_ENV=
    [ ${#SS_FIELDS[@]} -eq 0 ] || {
        # This works because cloud-init does no unescaping
        STACKSCRIPT_ENV=$(lk_echo_array SS_FIELDS | sort)
    }
fi

while VM_STATE=$(lk_maybe_sudo virsh domstate "$VM_HOSTNAME" 2>/dev/null); do
    [ "$VM_STATE" != "shut off" ] || unset VM_STATE
    lk_console_error "Domain already exists:" "$VM_HOSTNAME"
    PROMPT=(
        "OK to"
        ${VM_STATE+"force off,"}
        "delete and permanently remove all storage volumes?"
    )
    lk_is_true FORCE_DELETE ||
        LK_FORCE_INPUT=1 lk_confirm "${PROMPT[*]}" N ||
        lk_die ""
    [ -z "${VM_STATE+1}" ] ||
        lk_maybe_sudo virsh destroy "$VM_HOSTNAME" || true
    lk_maybe_sudo virsh undefine --remove-all-storage "$VM_HOSTNAME" || true
done

lk_console_message "Provisioning:"
_VM_PACKAGES=${VM_PACKAGES//,/, }
printf '%s\t%s\n' \
    "Name" "$LK_BOLD$VM_HOSTNAME$LK_RESET" \
    "Image" "$IMAGE_NAME" \
    "Refresh if cached" "${REFRESH_CLOUDIMG:-no}" \
    "Packages" "${_VM_PACKAGES:-<none>}" \
    "Filesystem maps" "${VM_FILESYSTEM_MAPS:-<none>}" \
    "Memory" "$VM_MEMORY" \
    "CPUs" "$VM_CPUS" \
    "Disk size" "$VM_DISK_SIZE" \
    "Network" "$VM_NETWORK" \
    "IPv4 address" "${VM_IPV4_ADDRESS:-<automatic>}" \
    "MAC address" "$VM_MAC_ADDRESS" \
    "StackScript" "${STACKSCRIPT:-<none>}" \
    "Custom metadata" "${#METADATA_URLS[@]} namespace$(lk_maybe_plural \
        ${#METADATA_URLS[@]} "" s)" \
    "Libvirt service" "$LIBVIRT_URI" \
    "Disk image path" "$VM_POOL_ROOT" | IFS=$'\t' lk_tty_detail_pairs
[ -z "$STACKSCRIPT" ] ||
    lk_console_detail "StackScript environment:" $'\n'"${STACKSCRIPT_ENV:-<empty>}"
lk_console_blank
lk_confirm "OK to proceed?" Y || lk_die ""

{
    lk_elevate_if_error install -d -m 0777 \
        "$LK_BASE/var/cache"{,/cloud-images,/NoCloud} 2>/dev/null &&
        cd "$LK_BASE/var/cache/cloud-images" ||
        lk_die "error creating cache directories"

    #####

    FILENAME="${IMAGE_URL##*/}"
    IMG_NAME="${FILENAME%.*}"

    if [ ! -f "$FILENAME" ] || lk_is_true REFRESH_CLOUDIMG; then

        lk_console_item "Downloading" "$FILENAME"

        wget --timestamping "$IMAGE_URL" || {
            rm -f "$FILENAME"
            lk_die "error downloading $IMAGE_URL"
        }

        if [ "${#SHA_URLS[@]}" -eq "1" ]; then
            SHA_SUMS="$(curl "${SHA_URLS[0]}" | gpg ${SHA_KEYRING:+--no-default-keyring --keyring "$SHA_KEYRING"} --decrypt)" || lk_die "error verifying ${SHA_URLS[0]}"
        else
            SHA_SUMS="$(curl "${SHA_URLS[1]}")" &&
                gpg ${SHA_KEYRING:+--no-default-keyring --keyring "$SHA_KEYRING"} --verify <(curl "${SHA_URLS[0]}") <(echo "$SHA_SUMS") || lk_die "error verifying ${SHA_URLS[0]}"
        fi
        echo "$SHA_SUMS" >"SHASUMS-$IMAGE_NAME" || lk_die "error writing to SHASUMS-$IMAGE_NAME"

    fi

    TIMESTAMP="$(gnu_stat --printf '%Y' "$FILENAME")"
    CLOUDIMG_PATH="$CLOUDIMG_ROOT/cloud-images/$IMG_NAME-$TIMESTAMP.qcow2"
    if sudo test -f "$CLOUDIMG_PATH"; then
        lk_console_message "$FILENAME is already available at $CLOUDIMG_PATH"
    else
        grep -E "$(lk_escape_ere "$FILENAME")\$" "SHASUMS-$IMAGE_NAME" | shasum -a "${SHA_ALGORITHM:-256}" -c &&
            lk_console_item "Verified" "$FILENAME" "$LK_BOLD$LK_GREEN" ||
            lk_die "$PWD/$FILENAME: verification failed"
        sudo chmod -c 755 "$CLOUDIMG_ROOT" # some distros (e.g. Ubuntu) make this root-only by default
        sudo mkdir -p "$CLOUDIMG_ROOT/cloud-images"
        CLOUDIMG_FORMAT="$(qemu-img info --output=json "$FILENAME" | jq -r .format)"
        if [ "$CLOUDIMG_FORMAT" != "qcow2" ]; then
            lk_console_message "Converting $FILENAME (format: $CLOUDIMG_FORMAT) to $CLOUDIMG_PATH"
            sudo qemu-img convert -pO qcow2 "$FILENAME" "$CLOUDIMG_PATH"
        else
            lk_console_message "Copying $FILENAME (format: $CLOUDIMG_FORMAT) to $CLOUDIMG_PATH"
            sudo cp -v "$FILENAME" "$CLOUDIMG_PATH"
        fi
        sudo touch -r "$FILENAME" "$CLOUDIMG_PATH" &&
            sudo chmod -v 444 "$CLOUDIMG_PATH" &&
            lk_console_message "$FILENAME is now available at $CLOUDIMG_PATH"
    fi

    DISK_PATH="$VM_POOL_ROOT/$VM_HOSTNAME-$IMG_NAME-$TIMESTAMP.qcow2"
    NOCLOUD_TEMP_PATH="$VM_HOSTNAME-$IMG_NAME-$TIMESTAMP-cloud-init.qcow2"
    NOCLOUD_PATH="$VM_POOL_ROOT/$NOCLOUD_TEMP_PATH"

    if [ -e "$DISK_PATH" ]; then
        lk_console_error "Disk image already exists:" "$DISK_PATH"
        lk_is_true FORCE_DELETE || LK_FORCE_INPUT=1 lk_confirm \
            "Destroy the existing image and start over?" N ||
            lk_die ""
    fi

    NETWORK_CONFIG="\
version: 1
config:
  - type: physical
    name: eth0
    mac_address: $VM_MAC_ADDRESS
    subnets:"

    if [ -n "$VM_IPV4_ADDRESS" ]; then
        SUBNET="${VM_IPV4_ADDRESS%%/*}"
        SUBNET="${SUBNET%.*}."
        NETWORK_CONFIG="\
$NETWORK_CONFIG
      - type: static
        address: $VM_IPV4_ADDRESS
        gateway: ${SUBNET}1
        dns_nameservers:
          - ${SUBNET}1"

    else
        NETWORK_CONFIG="\
$NETWORK_CONFIG
      - type: dhcp"

    fi

    OPTIONS=()
    FSTAB=()
    MOUNT_DIRS=()
    [ -z "$VM_FILESYSTEM_MAPS" ] || {
        IFS="|"
        # shellcheck disable=SC2206
        FILESYSTEMS=($VM_FILESYSTEM_MAPS)
        unset IFS

        for FILESYSTEM in "${FILESYSTEMS[@]}"; do
            IFS=","
            # shellcheck disable=SC2206
            FILESYSTEM_DIRS=($FILESYSTEM)
            unset IFS

            [ "${#FILESYSTEM_DIRS[@]}" -ge "2" ] || lk_die "invalid filesystem map: $FILESYSTEM"
            SOURCE_DIR="${FILESYSTEM_DIRS[0]}"
            MOUNT_DIR="${FILESYSTEM_DIRS[1]}"
            MOUNT_NAME="qemufs${#MOUNT_DIRS[@]}"
            [ -d "$SOURCE_DIR" ] || lk_die "$SOURCE_DIR: directory does not exist"

            FILESYSTEM_DIRS[1]="$MOUNT_NAME"
            IFS=","
            FILESYSTEM="${FILESYSTEM_DIRS[*]}"
            unset IFS

            OPTIONS+=(--filesystem "$FILESYSTEM")
            FSTAB+=("$MOUNT_NAME $MOUNT_DIR 9p defaults,nofail,trans=virtio,version=9p2000.L,posixacl,msize=262144,_netdev 0 0")
            MOUNT_DIRS+=("$MOUNT_DIR")
        done
    }

    [ -f "$HOME/.ssh/authorized_keys" ] || lk_die "$HOME/.ssh/authorized_keys: file not found"
    IFS=$'\n'
    # shellcheck disable=SC2207
    SSH_AUTHORIZED_KEYS=($(grep -Ev '^(#|\s*$)' "$HOME/.ssh/authorized_keys"))
    unset IFS
    [ "${#SSH_AUTHORIZED_KEYS[@]}" -gt "0" ] || lk_die "$HOME/.ssh/authorized_keys: no keys"

    PACKAGES=()
    [ "$IMAGE_NAME" = "ubuntu-12.04" ] || PACKAGES+=("qemu-guest-agent")
    [ -z "$VM_PACKAGES" ] || [ -n "$STACKSCRIPT" ] || {
        IFS=","
        # shellcheck disable=SC2206
        PACKAGES+=($VM_PACKAGES)
        unset IFS
    }

    RUN_CMD=()
    WRITE_FILES=()
    if [ -z "$STACKSCRIPT" ]; then
        USER_DATA="\
#cloud-config
ssh_pwauth: false
users:
  - uid: $UID
    name: $USER
    gecos: $(lk_full_name)
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
$(printf '      - %s\n' "${SSH_AUTHORIZED_KEYS[@]}")
package_upgrade: true
package_reboot_if_required: true
$(
            [ "$IMAGE_NAME" != "ubuntu-12.04" ] || printf '%s\n' \
                "apt_upgrade: true" \
                "ssh_authorized_keys:" "${SSH_AUTHORIZED_KEYS[@]/#/  - }"
        )"
    else
        USER_DATA="\
#cloud-config
ssh_pwauth: true
disable_root: false
users: []
ssh_authorized_keys:
$(printf '  - %s\n' "${SSH_AUTHORIZED_KEYS[@]}")"

        STACKSCRIPT_LINES="$(
            if lk_command_exists shfmt; then
                shfmt -mn "$STACKSCRIPT"
            else
                lk_warn "unable to minify $STACKSCRIPT (shfmt not installed)"
                cat "$STACKSCRIPT"
            fi | sed 's/^/      /'
        )"
        RUN_CMD+=(
            "  - - env"
            "    - ${STACKSCRIPT_ENV//$'\n'/$'\n'    - }"
            "    - bash"
            "    - -c"
            "    - |"
            "      exec </dev/null"
            "$STACKSCRIPT_LINES"
        )
    fi

    USER_DATA="$USER_DATA
apt:
  primary:
    - arches: [default]
      uri: ${LK_UBUNTU_APT_MIRROR:-http://archive.ubuntu.com/ubuntu}
$(
        [ "${#PACKAGES[@]}" -eq "0" ] ||
            printf '%s\n' "packages:" "${PACKAGES[@]/#/  - }"
        [ "${#FSTAB[@]}" -eq "0" ] || {
            FSTAB_CMD=("${FSTAB[@]/#/  - echo \"}")
            FSTAB_CMD=("${FSTAB_CMD[@]/%/\" >>/etc/fstab}")
            FSTAB_CMD+=("${MOUNT_DIRS[@]/#/  - mount }")
            RUN_CMD=(
                "  - mkdir -pv ${MOUNT_DIRS[*]}"
                "${FSTAB_CMD[@]}"
                ${RUN_CMD[@]+"${RUN_CMD[@]}"}
            )
        }
        # ubuntu-16.04-minimal leaves /etc/resolv.conf unconfigured if a static IP
        # is assigned (no resolvconf package?)
        [ -z "$VM_IPV4_ADDRESS" ] || [ "$IMAGE_NAME" != "ubuntu-16.04-minimal" ] ||
            WRITE_FILES+=(
                "  - content: |"
                "      nameserver ${SUBNET}1"
                "    path: /etc/resolv.conf"
            )
        # ubuntu-12.04 doesn't start a serial getty (or implement write_files)
        [ "$IMAGE_NAME" != "ubuntu-12.04" ] || {
            GETTY_SH='cat <<EOF >"/etc/init/ttyS0.conf"
start on stopped rc RUNLEVEL=[2345]
stop on runlevel [!2345]
respawn
exec /sbin/getty --keep-baud 115200,38400,9600 ttyS0 vt220
EOF
/sbin/initctl start ttyS0'
            RUN_CMD+=(
                "  - - bash"
                "    - -c"
                "    - |"
                "      ${GETTY_SH//$'\n'/$'\n'      }"
            )
        }
        # cloud-init on ubuntu-14.04 doesn't recognise the "apt" schema
        [[ ! "$IMAGE_NAME" =~ ^ubuntu-(14.04|12.04)$ ]] ||
            echo "\
apt_mirror: ${LK_UBUNTU_APT_MIRROR:-http://archive.ubuntu.com/ubuntu}"
        [ "${#RUN_CMD[@]}" -eq "0" ] || {
            printf '%s\n' \
                "runcmd:" \
                "${RUN_CMD[@]}"
        }
        [ "${#WRITE_FILES[@]}" -eq "0" ] || {
            printf '%s\n' \
                "write_files:" \
                "${WRITE_FILES[@]}"
        }
    )"

    META_DATA="\
dsmode: local
instance-id: $(uuidgen)
local-hostname: $VM_HOSTNAME
$(
        # cloud-init on ubuntu-14.04 ignores the network-config file
        [ -z "$VM_IPV4_ADDRESS" ] ||
            [[ ! "$IMAGE_NAME" =~ ^ubuntu-(14.04|12.04)$ ]] ||
            echo "\
network-interfaces: |
  auto eth0
  iface eth0 inet static
  address $VM_IPV4_ADDRESS
  gateway ${SUBNET}1
  dns-nameservers ${SUBNET}1"
    )"

    NOCLOUD_META_DIR="$LK_BASE/var/cache/NoCloud/$(lk_hostname)-$VM_HOSTNAME-$(lk_date_ymdhms)"
    install -d -m 00755 "$NOCLOUD_META_DIR"

    echo "$NETWORK_CONFIG" >"$NOCLOUD_META_DIR/network-config.yml"
    echo "$USER_DATA" >"$NOCLOUD_META_DIR/user-data.yml"
    echo "$META_DATA" >"$NOCLOUD_META_DIR/meta-data.yml"

    if lk_confirm "Customise cloud-init data source?" N -t 60; then
        xdg-open "$NOCLOUD_META_DIR" || :
        lk_pause "Press any key to continue after making changes in $NOCLOUD_META_DIR . . . "
    fi

    cloud-localds \
        -N "$NOCLOUD_META_DIR/network-config.yml" \
        -d qcow2 \
        "$NOCLOUD_TEMP_PATH" \
        "$NOCLOUD_META_DIR/user-data.yml" \
        "$NOCLOUD_META_DIR/meta-data.yml" &&
        lk_maybe_sudo cp -fv "$NOCLOUD_TEMP_PATH" "$NOCLOUD_PATH" &&
        rm -f "$NOCLOUD_TEMP_PATH" || lk_die

    lk_maybe_sudo qemu-img create \
        -f "qcow2" \
        -b "$CLOUDIMG_PATH" \
        -F "qcow2" \
        "$DISK_PATH" &&
        lk_maybe_sudo qemu-img resize \
            -f "qcow2" \
            "$DISK_PATH" \
            "$VM_DISK_SIZE" || lk_die

    VM_NETWORK_TYPE="${VM_NETWORK%%=*}"
    if [ "$VM_NETWORK_TYPE" = "$VM_NETWORK" ]; then
        VM_NETWORK_TYPE=network
    else
        VM_NETWORK="${VM_NETWORK#*=}"
    fi

    FILE=$(lk_mktemp_file)
    lk_delete_on_exit "$FILE"
    lk_maybe_sudo virt-install \
        --connect "$LIBVIRT_URI" \
        --name "$VM_HOSTNAME" \
        --memory "$VM_MEMORY" \
        --vcpus "$VM_CPUS" \
        --import \
        --os-variant "$OS_VARIANT" \
        --disk "$DISK_PATH",bus=virtio \
        --disk "$NOCLOUD_PATH",bus=virtio \
        --network "$VM_NETWORK_TYPE=$VM_NETWORK,mac=$VM_MAC_ADDRESS,model=virtio" \
        --graphics none \
        ${OPTIONS[@]+"${OPTIONS[@]}"} \
        --virt-type kvm \
        --print-xml >"$FILE"
    lk_maybe_sudo virsh define "$FILE"
    for i in $([ ${#METADATA[@]} -eq 0 ] || seq 0 3 $((${#METADATA[@]} - 1))); do
        lk_maybe_sudo virsh metadata "$VM_HOSTNAME" \
            "${METADATA[@]:i:3}"
    done
    lk_maybe_sudo virsh start "$VM_HOSTNAME" --console

    exit
}
