#!/bin/bash
# Imports DoD root certificates into the Linux CA store.
# Based on version 0.4.2 (20250425) by AfroThundr -- locally modified.
# SPDX-License-Identifier: GPL-3.0-or-later

# For issues or updated versions of this script, browse to the following URL:
# https://gist.github.com/AfroThundr3007730/ba99753dda66fc4abaf30fb5c0e5d012

# Local changes, which need carrying forward if this is ever refreshed from
# upstream:
#
#   * Idempotent. Upstream unconditionally rewrote every certificate and ran
#     the trust-store update command on each invocation, which is the slow part
#     and which made the Ansible task that calls this report a change forever.
#     Certificates are now staged in the temp directory, normalised, and
#     compared against what is already installed; only the ones that differ are
#     written, and the update command runs only if at least one did.
#
#     One consequence worth expecting: the first run after this change rewrites
#     every certificate, because upstream left the "subject=" header line that
#     `openssl pkcs7 -print_certs` emits inside each .crt and this does not.
#     The run after that is a no-op.
#
#   * Exit status distinguishes the two outcomes, following diff(1):
#         0  trust store already matched the bundle, nothing written
#         2  certificates were written and the trust store was updated
#         1  error
#
#   * gawk is invoked by name and checked for up front. The rename step uses
#     gensub(), which is a gawk extension: on Ubuntu, where the default awk is
#     mawk, it failed at runtime with the download and the split already done.
#
#   * Runs as root and the trust store's writability are checked before the
#     download rather than discovered after it.

# Dependencies: cmp gawk openssl unzip wget

set -euo pipefail
shopt -s extdebug nullglob

add_dod_certs() {
    local bundle cert certdir changed dep file form name tmpdir url update
    trap '[[ -d ${tmpdir:-} ]] && rm -fr $tmpdir' EXIT INT TERM

    for dep in cmp gawk openssl unzip wget; do
        command -v "$dep" >/dev/null || {
            printf 'Missing required command: %s\n' "$dep" >&2
            exit 1
        }
    done

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
        ${ID:-} == cachyos ||
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

    # Fail on this before spending a download on it, not after.
    [[ $EUID -eq 0 ]] || {
        printf 'Must run as root to write to %s.\n' "$certdir" >&2
        exit 1
    }
    [[ -d $certdir ]] || mkdir -p "$certdir"

    # Extract the bundle
    wget -qP "${tmpdir:=$(mktemp -d)}" "$bundle"
    unzip -qj "$tmpdir"/"${bundle##*/}" -d "$tmpdir"

    # Check for existence of PEM or DER format p7b.
    for file in "$tmpdir"/*_{DoD,dod}{.,_}{pem,der}.p7b; do
        # Iterate over glob instead of testing directly (SC2144)
        [[ -f ${file:-} ]] &&
            form=${file%.*} && form=${form##*_} && form=${form##*.} && break
    done
    [[ ${form:-} && ${file:-} ]] || { printf 'No bundles found!\n' >&2 && exit 1; }

    # Convert the PKCS#7 bundle into individual PEM files. Staged in their own
    # subdirectory so the glob below cannot pick up the zip or the p7b.
    mkdir -p "$tmpdir"/staged
    openssl pkcs7 -print_certs -inform "$form" -in "$file" |
        gawk -v d="$tmpdir"/staged \
            'BEGIN {c=0} /subject=/ {c++} {print > d "/cert." c ".pem"}'

    # Name each staged certificate after its CA, then install only the ones
    # that are missing or different. Comparing before copying is what makes a
    # second run a no-op, and what keeps $update -- the expensive step -- from
    # running when there is nothing to rebuild.
    changed=0
    for cert in "$tmpdir"/staged/cert.*.pem; do
        name=$(
            openssl x509 -noout -subject -in "$cert" |
                gawk -F '(=|= )' '{print gensub(/ /, "_", "g", $NF)}'
        )
        # Round-tripping through `openssl x509` drops the "subject=" header
        # that -print_certs put at the top of each block. Without that the
        # comparison would be against a file the trust store never sees the
        # same way twice.
        openssl x509 -in "$cert" -out "$tmpdir"/staged/"$name".crt

        [[ -f $certdir/$name.crt ]] &&
            cmp -s "$tmpdir"/staged/"$name".crt "$certdir/$name.crt" && continue

        install -m 0644 "$tmpdir"/staged/"$name".crt "$certdir/$name.crt"
        changed=$((changed + 1))
    done

    # Remove temp files and update certificate stores
    rm -fr "$tmpdir"

    (( changed )) || {
        printf 'DoD certificates already up to date in %s.\n' "$certdir"
        return 0
    }

    printf 'Wrote %s DoD certificate(s) to %s, updating trust store.\n' \
        "$changed" "$certdir"
    $update
    return 2
}

# Only execute if not being sourced
[[ ${BASH_SOURCE[0]} == "$0" ]] || return 0 && add_dod_certs "$@"
