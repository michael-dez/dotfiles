#!/bin/bash
# Imports DoD root certificates into Linux CA store
# Version 0.4.2 updated 20250425 by AfroThundr
# SPDX-License-Identifier: GPL-3.0-or-later

# For issues or updated versions of this script, browse to the following URL:
# https://gist.github.com/AfroThundr3007730/ba99753dda66fc4abaf30fb5c0e5d012

# Dependencies: curl gawk openssl unzip wget

set -euo pipefail
shopt -s extdebug nullglob

add_dod_certs() {
    local bundle cert certdir file form tmpdir url update
    trap '[[ -d ${tmpdir:-} ]] && rm -fr $tmpdir' EXIT INT TERM

    # Location of bundle from DISA site
    url='https://dl.dod.cyber.mil/wp-content/uploads/pki-pke/zip/'
    bundle=${url}unclass-certificates_pkcs7_DoD.zip

    # Set cert directory and update command based on OS
    [[ -f /etc/os-release ]] && source /etc/os-release
    if [[ ${ID:-} =~ (fedora|rhel|centos) ||
        ${ID_LIKE:-} =~ (fedora|rhel|centos) ]]; then
        certdir=/etc/pki/ca-trust/source/anchors
        update='update-ca-trust'
    elif [[ ${ID:-} =~ (debian|ubuntu|mint) ||
        ${ID_LIKE:-} =~ (debian|ubuntu|mint) ]]; then
        certdir=/usr/local/share/ca-certificates
        update='update-ca-certificates'
    elif [[ ${ID:-} =~ (arch) ||
        ${ID_LIKE:-} =~ (arch) ]]; then
        certdir=/etc/ca-certificates/trust-source/anchors
        update='update-ca-trust'
    else
        certdir=${1:-} && update=${2:-}
    fi

    [[ ${certdir:-} && ${update:-} ]] || {
        printf 'Unable to autodetect OS using /etc/os-release.\n'
        printf 'Please provide CA certificate directory and update command.\n'
        printf 'Example: %s /cert/store/location update-cmd\n' "${0##*/}"
        exit 1
    }

    # Extract the bundle
    wget -qP "${tmpdir:=$(mktemp -d)}" "$bundle"
    unzip -qj "$tmpdir"/"${bundle##*/}" -d "$tmpdir"

    # Check for existence of PEM or DER format p7b.
    for file in "$tmpdir"/*_{DoD,dod}{.,_}{pem,der}.p7b; do
        # Iterate over glob instead of testing directly (SC2144)
        [[ -f ${file:-} ]] && 
            form=${file%.*} && form=${form##*_} && form=${form##*.} && break
    done
    [[ ${form:-} && ${file:-} ]] || { printf 'No bundles found!\n' && exit 1; }

    # Convert the PKCS#7 bundle into individual PEM files
    openssl pkcs7 -print_certs -inform "$form" -in "$file" |
        awk -v d="$tmpdir" \
            'BEGIN {c=0} /subject=/ {c++} {print > d "/cert." c ".pem"}'

    # Rename the files based on the CA name
    for cert in "$tmpdir"/cert.*.pem; do
        mv "$cert" "$certdir"/"$(
            openssl x509 -noout -subject -in "$cert" |
                awk -F '(=|= )' '{print gensub(/ /, "_", "g", $NF)}'
        )".crt
    done

    # Remove temp files and update certificate stores
    rm -fr "$tmpdir" && $update
}

# Only execute if not being sourced
[[ ${BASH_SOURCE[0]} == "$0" ]] || return 0 && add_dod_certs "$@"
