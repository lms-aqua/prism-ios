FROM debian:bookworm-slim

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends samba iproute2 \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --uid 1000 --no-create-home --shell /usr/sbin/nologin lost \
    && useradd --uid 2000 --no-create-home --shell /usr/sbin/nologin prismshare

COPY smb.conf /etc/samba/smb.conf
COPY start.sh /usr/local/bin/start-samba
RUN chmod 0755 /usr/local/bin/start-samba

EXPOSE 445
ENTRYPOINT ["/usr/local/bin/start-samba"]
