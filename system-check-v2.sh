#!/bin/bash

# Void Linux desktop security / health checklist v2
# Read-only: this script does not modify the system.
#
# Intended for:
#   Void Linux + runit + KDE Plasma + SDDM
#
# It checks:
#   - Void / kernel
#   - runit services
#   - nftables ruleset and common firewall properties
#   - listening network sockets
#   - IP forwarding
#   - LUKS / encrypted block devices
#   - swap / zram / swappiness
#   - Secure Boot (UEFI variable; mokutil if available)
#   - current user / wheel membership
#   - KDE screen-lock service (best effort)
#   - pending XBPS updates
#
# It deliberately does NOT:
#   - change configuration
#   - start/stop services
#   - install packages
#   - modify firewall rules
#   - perform an external port scan
#
# Exit status is 0 unless the script itself cannot run normally.
# WARN/FAIL below are informational; review the actual output.

set +e

PASS=0
WARN=0
FAIL=0

if [[ $EUID -eq 0 ]]; then
    SUDO=""
else
    SUDO="sudo"
fi

green() {
    printf '\033[32m[ OK ]\033[0m %s\n' "$1"
    ((PASS++))
}

yellow() {
    printf '\033[33m[WARN]\033[0m %s\n' "$1"
    ((WARN++))
}

red() {
    printf '\033[31m[FAIL]\033[0m %s\n' "$1"
    ((FAIL++))
}

info() {
    printf '\033[36m[INFO]\033[0m %s\n' "$1"
}

section() {
    echo
    echo "============================================================"
    echo " $1"
    echo "============================================================"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ------------------------------------------------------------
section "SYSTEM"
# ------------------------------------------------------------

if command_exists xbps-install; then
    green "XBPS detected - this is a Void Linux system."
else
    red "xbps-install not found."
fi

info "Hostname: $(hostname 2>/dev/null)"
info "Kernel:   $(uname -r 2>/dev/null)"
info "Uptime:   $(uptime -p 2>/dev/null)"

# ------------------------------------------------------------
section "RUNIT / SERVICES"
# ------------------------------------------------------------

if command_exists sv; then
    if [[ -e /var/service/dbus ]]; then
        if $SUDO sv status dbus >/dev/null 2>&1; then
            green "D-Bus service is running."
        else
            yellow "D-Bus service exists but is not reported as running."
        fi
    else
        info "No /var/service/dbus symlink found."
    fi

    if [[ -e /var/service/sddm ]]; then
        if $SUDO sv status sddm >/dev/null 2>&1; then
            green "SDDM service is running."
        else
            yellow "SDDM service exists but is not reported as running."
        fi
    else
        info "No /var/service/sddm symlink found."
    fi

    if [[ -d /var/service ]]; then
        echo
        info "Enabled runit services:"
        find -L /var/service -maxdepth 1 -mindepth 1 -printf '%f\n' 2>/dev/null \
            | sort | sed 's/^/    /'
    fi
else
    red "runit 'sv' command not found."
fi

# ------------------------------------------------------------
section "NFTABLES"
# ------------------------------------------------------------

if ! command_exists nft; then
    red "nft command not found."
else
    green "nft command is installed."

    if $SUDO nft list ruleset >/dev/null 2>&1; then
        green "nftables ruleset can be read."
    else
        red "Cannot read nftables ruleset."
    fi

    RULESET="$($SUDO nft list ruleset 2>/dev/null)"

    if [[ -z "$RULESET" ]]; then
        red "nftables ruleset is empty."
    else
        green "A non-empty nftables ruleset exists."

        echo
        info "Tables:"
        echo "$RULESET" |
            grep -E '^[[:space:]]*table (inet|ip|ip6|bridge|arp|netdev)' |
            sed 's/^/    /'

        echo
        info "Base-chain policies:"
        POLICIES=$(echo "$RULESET" |
            grep -E 'hook (input|output|forward)' |
            grep -E 'policy (accept|drop|reject)' || true)

        if [[ -n "$POLICIES" ]]; then
            echo "$POLICIES" | sed 's/^/    /'
        else
            yellow "Could not identify base-chain policies."
        fi

        # Input policy: only report restrictive default if clearly present.
        if echo "$RULESET" |
            grep -Eq 'hook[[:space:]]+input.*policy[[:space:]]+(drop|reject)'; then
            green "Input base chain has DROP/REJECT default policy."
        elif echo "$RULESET" |
            grep -Eq 'hook[[:space:]]+input.*policy[[:space:]]+accept'; then
            yellow "Input base chain has ACCEPT default policy."
        else
            info "Input base-chain default policy could not be determined."
        fi

        # Forward policy.
        if echo "$RULESET" |
            grep -Eq 'hook[[:space:]]+forward.*policy[[:space:]]+(drop|reject)'; then
            green "Forward base chain has DROP/REJECT default policy."
        elif echo "$RULESET" |
            grep -Eq 'hook[[:space:]]+forward.*policy[[:space:]]+accept'; then
            yellow "Forward base chain has ACCEPT default policy."
        else
            info "No forward base chain with an explicit policy was identified."
        fi

        # Loopback: avoid pretending absence is definitely unsafe.
        if echo "$RULESET" |
            grep -Eq '(^|[[:space:]])iif(name)?[[:space:]]+"?lo"?([[:space:]]|$)'; then
            green "Ruleset contains an explicit loopback input rule."
        else
            info "No obvious explicit loopback input rule detected."
        fi

        # Established/related.
        if echo "$RULESET" |
            grep -Eq 'ct[[:space:]]+state[[:space:]]+[^;]*(established|related)'; then
            green "Ruleset appears to handle established/related connections."
        else
            info "No obvious established/related rule detected."
        fi

        # IPv6 support.
        if echo "$RULESET" | grep -Eq '^[[:space:]]*table[[:space:]]+inet|^[[:space:]]*table[[:space:]]+ip6'; then
            green "Ruleset contains IPv6-capable rules."
        else
            yellow "No inet/ip6 table detected; review IPv6 firewalling if IPv6 is enabled."
        fi

        echo
        info "Full nftables ruleset:"
        echo "$RULESET"
    fi
fi

# ------------------------------------------------------------
section "LISTENING NETWORK SERVICES"
# ------------------------------------------------------------

if command_exists ss; then
    LISTENING="$(ss -lntup 2>/dev/null)"

    if [[ -n "$LISTENING" ]]; then
        info "Listening TCP/UDP sockets:"
        echo "$LISTENING"

        echo
        info "Tip: every unexpected listening service deserves investigation."
    else
        green "No listening network sockets detected."
    fi
else
    yellow "ss command not available."
fi

# ------------------------------------------------------------
section "IP FORWARDING"
# ------------------------------------------------------------

IPV4_FORWARD=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)
IPV6_FORWARD=$(cat /proc/sys/net/ipv6/conf/all/forwarding 2>/dev/null)

if [[ "$IPV4_FORWARD" == "0" ]]; then
    green "IPv4 forwarding is disabled."
elif [[ "$IPV4_FORWARD" == "1" ]]; then
    yellow "IPv4 forwarding is ENABLED."
else
    info "Could not determine IPv4 forwarding state."
fi

if [[ "$IPV6_FORWARD" == "0" ]]; then
    green "IPv6 forwarding is disabled."
elif [[ "$IPV6_FORWARD" == "1" ]]; then
    yellow "IPv6 forwarding is ENABLED."
else
    info "Could not determine IPv6 forwarding state."
fi

# ------------------------------------------------------------
section "FDE / LUKS"
# ------------------------------------------------------------

if command_exists lsblk; then
    echo
    lsblk -o NAME,TYPE,FSTYPE,SIZE,MOUNTPOINTS 2>/dev/null

    LUKS_COUNT=$(lsblk -o FSTYPE 2>/dev/null |
        grep -cE 'crypto_LUKS|crypt' || true)

    if [[ "$LUKS_COUNT" -gt 0 ]]; then
        green "LUKS/encrypted block device detected."
    else
        info "No LUKS device was identified by lsblk."
    fi
else
    yellow "lsblk command not available."
fi

# ------------------------------------------------------------
section "SWAP / MEMORY"
# ------------------------------------------------------------

if command_exists swapon; then
    SWAP="$(swapon --show 2>/dev/null)"

    if [[ -n "$SWAP" ]]; then
        green "Swap is active."
        echo "$SWAP"
    else
        yellow "No active swap detected."
    fi
else
    yellow "swapon command not available."
fi

if [[ -e /sys/block/zram0 ]]; then
    green "zram0 device exists."

    if command_exists zramctl; then
        zramctl
    fi
else
    info "No zram0 device detected."
fi

echo
info "Memory:"
free -h 2>/dev/null

# ------------------------------------------------------------
section "SWAPPINESS"
# ------------------------------------------------------------

SWAPPINESS=$(cat /proc/sys/vm/swappiness 2>/dev/null)

if [[ -n "$SWAPPINESS" ]]; then
    info "vm.swappiness = $SWAPPINESS"

    if (( SWAPPINESS >= 0 && SWAPPINESS <= 100 )); then
        green "swappiness is within the normal kernel range."
    else
        yellow "Unusual swappiness value."
    fi
fi

# ------------------------------------------------------------
section "SECURE BOOT"
# ------------------------------------------------------------

if [[ ! -d /sys/firmware/efi ]]; then
    info "System is not booted in UEFI mode; Secure Boot is unavailable."
else
    SB_RESULT=""

    # Preferred human-readable method when mokutil is available.
    if command_exists mokutil; then
        SB_RESULT="$(mokutil --sb-state 2>/dev/null)"
    fi

    if echo "$SB_RESULT" | grep -qiE 'SecureBoot[[:space:]]+enabled|SecureBoot:[[:space:]]+enabled'; then
        green "Secure Boot is ENABLED (mokutil)."
    elif echo "$SB_RESULT" | grep -qiE 'SecureBoot[[:space:]]+disabled|SecureBoot:[[:space:]]+disabled'; then
        yellow "Secure Boot is DISABLED (mokutil)."
    else
        # Fallback: EFI SecureBoot variable, whose data byte is offset 4.
        SB_FILE=$(find /sys/firmware/efi/efivars \
            -maxdepth 1 -name 'SecureBoot-*' 2>/dev/null | head -n1)

        if [[ -z "$SB_FILE" ]]; then
            yellow "Secure Boot EFI variable not found."
        else
            SB_STATE=$(od -An -t u1 -j 4 -N 1 "$SB_FILE" 2>/dev/null | tr -d ' ')

            case "$SB_STATE" in
                1)
                    green "Secure Boot is ENABLED (EFI variable)."
                    ;;
                0)
                    yellow "Secure Boot is DISABLED (EFI variable)."
                    ;;
                *)
                    yellow "Could not determine Secure Boot state."
                    ;;
            esac
        fi
    fi
fi

# ------------------------------------------------------------
section "USER / PRIVILEGES"
# ------------------------------------------------------------

CURRENT_USER="$(id -un 2>/dev/null)"
CURRENT_GROUPS="$(id -nG 2>/dev/null)"

info "Current user: $CURRENT_USER"
info "UID/GID:      $(id -u 2>/dev/null)/$(id -g 2>/dev/null)"
info "Groups:       $CURRENT_GROUPS"

if [[ "$(id -u 2>/dev/null)" -eq 0 ]]; then
    yellow "The checklist is being run as root."
else
    green "Running as a normal user."
fi

if echo " $CURRENT_GROUPS " | grep -q ' wheel '; then
    green "Current user is in the wheel group."
else
    yellow "Current user is not in the wheel group."
fi

if command_exists sudo; then
    if sudo -n true >/dev/null 2>&1; then
        green "sudo is available without an additional password prompt right now."
    else
        info "sudo is installed; a password may be required."
    fi
else
    info "sudo is not installed."
fi

# ------------------------------------------------------------
section "KDE / SCREEN LOCK"
# ------------------------------------------------------------

LOCK_CHECKED=0

if command_exists qdbus6; then
    LOCK_ACTIVE="$(qdbus6 org.freedesktop.ScreenSaver \
        /ScreenSaver org.freedesktop.ScreenSaver.GetActive 2>/dev/null)"
    LOCK_CHECKED=1
elif command_exists qdbus; then
    LOCK_ACTIVE="$(qdbus org.freedesktop.ScreenSaver \
        /ScreenSaver org.freedesktop.ScreenSaver.GetActive 2>/dev/null)"
    LOCK_CHECKED=1
fi

if [[ "$LOCK_CHECKED" -eq 1 ]]; then
    if [[ "$LOCK_ACTIVE" == "true" ]]; then
        info "KDE screen-lock service is responding (currently locked)."
    elif [[ "$LOCK_ACTIVE" == "false" ]]; then
        green "KDE screen-lock service is responding (currently unlocked)."
    else
        info "KDE screen-lock service responded unexpectedly; manual check recommended."
    fi
else
    info "qdbus/qdbus6 not available; KDE lock service not checked."
fi

# ------------------------------------------------------------
section "XBPS UPDATES"
# ------------------------------------------------------------

if command_exists xbps-install; then
    info "Checking for available package updates..."

    UPDATES="$(xbps-install -Mun 2>/dev/null)"

    if [[ -z "$UPDATES" ]]; then
        green "No pending package updates detected."
    else
        yellow "Pending package updates exist:"
        echo "$UPDATES" | head -30
    fi
fi

# ------------------------------------------------------------
section "SSH KEY PERMISSIONS"
# ------------------------------------------------------------

if [[ -d "$HOME/.ssh" ]]; then
    SSH_PERM=$(stat -c '%a' "$HOME/.ssh" 2>/dev/null)

    if [[ "$SSH_PERM" == "700" ]]; then
        green "~/.ssh permissions are 700."
    else
        yellow "~/.ssh permissions are $SSH_PERM (700 is recommended)."
    fi

    shopt -s nullglob
    for f in "$HOME/.ssh/"id_*; do
        [[ -f "$f" ]] || continue

        # Skip public keys.
        [[ "$f" == *.pub ]] && continue

        PERM=$(stat -c '%a' "$f" 2>/dev/null)

        case "$PERM" in
            600|400)
                green "$(basename "$f") permissions are restrictive ($PERM)."
                ;;
            *)
                yellow "$(basename "$f") permissions are $PERM."
                ;;
        esac
    done
    shopt -u nullglob
else
    info "~/.ssh does not exist."
fi

# ------------------------------------------------------------
section "SUMMARY"
# ------------------------------------------------------------

echo
printf '\033[32mOK:   %d\033[0m\n' "$PASS"
printf '\033[33mWARN: %d\033[0m\n' "$WARN"
printf '\033[31mFAIL: %d\033[0m\n' "$FAIL"
echo

if (( FAIL == 0 && WARN == 0 )); then
    echo "Overall: everything checked looks good."
elif (( FAIL == 0 )); then
    echo "Overall: no hard failure detected; review the WARN items."
else
    echo "Overall: at least one important check failed."
fi

echo
echo "This is a lightweight checklist, not a full security audit."
