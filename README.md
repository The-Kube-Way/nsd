# NSD on Kubernetes

![Docker](https://github.com/the-kube-way/nsd/workflows/Docker/badge.svg?branch=master)
[![Project Status: Active – The project has reached a stable, usable state and is being actively developed.](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)

## What is this software

[NSD](https://www.nlnetlabs.nl/projects/nsd/about/) is an authoritative only, high performance, simple and open source name server released under the BSD licence.
This work is originally based on [hardware/nsd-dnssec](https://github.com/hardware/nsd-dnssec).

### Features

- Lightweight & secure image (based on Alpine & multi-stage build: 4MB, no root process)
- Latest NSD version with hardening compilation options
- Helper scripts for generating ZSK and KSK keys, DS-Records management and zone signature
- Optimized to be run on Kubernetes with ConfigMap

### Run on Kubernetes

See [docs/KUBERNETES.md](docs/KUBERNETES.md)

### Run with Docker-compose

```yaml
version: '3.7'

services:
  nsd:
    container_name: nsd
    restart: always
    image: ghcr.io/the-kube-way/nsd:latest
    read_only: true
    tmpfs:
      - /tmp
      - /var/db/nsd
    volumes:
      - /mnt/nsd/conf:/etc/nsd:ro
      - /mnt/nsd/zones:/zones
      - /mnt/nsd/keys:/keys:ro
    ports:
      - 53:53
      - 53:53/udp
```

**Ensure mount points match UID/GID (991 by default) used by nsd.**

`/etc/nsd` should be mounted read-only.  
`/zones` can be mounted read-only if helper scripts (e.g. for dnssec) are not used.  
`/keys` should be mounted read-only if keygen helper script is not used.

#### Configuration example

Put your dns zone file in `/mnt/nsd/zones/domain.tld`.

```bind
$ORIGIN domain.tld.
$TTL 3600

; SOA
; SOA record should be on one line to use provided helper scripts
@   IN   SOA   ns1.domain.tld. hostmaster.domain.tld. 2016020202 7200 1800 1209600 86400

; NAMESERVERS
@                   IN                NS                   ns1.domain.tld.
@                   IN                NS                   ns2.domain.tld.

; A RECORDS
@                   IN                A                    1.2.3.4
www                 IN                A                    5.6.7.8

...
```

Put the nsd config in `/mnt/nsd/conf/nsd.conf`.

```yaml
server:
  server-count: 1
  verbosity: 1
  hide-version: yes
  zonesdir: "/zones"

zone:
  name: domain.tld
  #zonefile: domain.tld  # if not signed
  zonefile: domain.tld.signed
```

Check the [documentation](https://www.nlnetlabs.nl/documentation/nsd/) to see all options.

#### Check the configuration

Check your zone and nsd configuration:

```sh
cd /mnt/nsd
docker run -it --rm -v $(pwd)/zones:/zones selfhostingtools/nsd nsd-checkzone domain.tld /zones/domain.tld
docker run -it --rm -v $(pwd)/conf:/etc/nsd selfhostingtools/nsd nsd-checkconf /etc/nsd/nsd.conf
```

#### Environment variables

You may want to change the running user:

| Variable | Description  | Type       | Default value |
| -------- | -----------  | ----       | ------------- |
| **UID**  | nsd user id  | *optional* | 991           |
| **GID**  | nsd group id | *optional* | 991           |

### Generating DNSSEC keys and signed zone

Generate ZSK and KSK keys with ECDSAP384SHA384 algorithm:

```sh
docker-compose exec nsd keygen domain.tld
```

Keys will be stored in `/keys/Kdomain.tld.{zsk,ksk}.{key,private}`

Then sign your dns zone (default expiration date is 1 month):

```sh
docker-compose exec nsd signzone domain.tld

# or set custom RRSIG RR expiration date:
docker-compose exec nsd signzone domain.tld [YYYYMMDDhhmmss]
```

:warning: **Do not forget to add a cron task to sign your zone periodically to avoid the expiration of RRSIG RR records!**

This can be done using systemd timer on the host:

`/etc/systemd/system/nsd_update_signature.service`

```systemd
[Unit]
Description=NSD update signature

[Service]
Type=oneshot
ExecStart=docker exec nsd signzone domain.tld
```

`/etc/systemd/system/nsd_update_signature.timer`

```systemd
[Timer]
OnCalendar=weekly

[Install]
WantedBy=multi-user.target
```

Don't forget to enable and start the timer!

Show your DS-Records (Delegation Signer):

```sh
docker-compose exec nsd ds-records domain.tld
```

Ensure zonefile parameter is correctly set (e.g. domain.tld.signed) in **nsd.conf**.

Restart nsd to take the changes into account:

```sh
docker-compose restart nsd
```

## Build the image

Build-time variables:

- **NSD_VERSION** : version of NSD
- **GPG_FINGERPRINT** : fingerprint of signing key
- **SHA256_HASH** : SHA256 hash of NSD archive
