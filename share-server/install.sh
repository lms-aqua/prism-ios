#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
password_dir="/home/lost/.config/prism-ios-share"
password_file="$password_dir/password"

mkdir -p "$password_dir"
chmod 700 "$password_dir"
if [[ ! -s "$password_file" ]]; then
    openssl rand -hex 24 > "$password_file"
    chmod 600 "$password_file"
fi

docker build -t prism-ios-samba:local "$script_dir"
docker rm -f prism-ios-smb >/dev/null 2>&1 || true
docker run -d \
    --name prism-ios-smb \
    --restart unless-stopped \
    --network host \
    --env PRISM_SMB_PASSWORD="$(<"$password_file")" \
    --volume /home/lost/apps/prism-ios:/share:rw \
    prism-ios-samba:local

printf 'Share ready: \\\\100.120.148.96\\prism-ios\n'
printf 'Username: prismshare\nPassword file: %s\n' "$password_file"
