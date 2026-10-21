# Windows share

This small Samba service exposes the `prism-ios` folder to clients from the
Tailscale IPv4 range. Run `./share-server/install.sh` from this directory
to build and start it. The script stores a generated share password in
`/home/lost/.config/prism-ios-share/password` with owner-only permissions.

On Windows, map `\\100.120.148.96\prism-ios` as a network drive. Use username
`prismshare` and the generated password. You can retrieve it on the server with
`cat /home/lost/.config/prism-ios-share/password`.
