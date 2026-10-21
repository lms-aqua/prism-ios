#!/bin/sh
set -eu

while ! ip -4 addr show dev tailscale0 2>/dev/null | grep -q '100\.120\.148\.96/'; do
    sleep 2
done

if [ ! -f /var/lib/samba/private/passdb.tdb ] || ! pdbedit -L | grep -q '^prismshare:'; then
    printf '%s\n%s\n' "$PRISM_SMB_PASSWORD" "$PRISM_SMB_PASSWORD" | smbpasswd -s -a prismshare
fi

exec smbd --foreground --no-process-group --debug-stdout
