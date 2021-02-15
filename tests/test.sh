#!/bin/sh

set -euxo pipefail

CONTAINER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' nsd)


# check zone
docker exec nsd nsd-checkzone example.org /zones/example.org | grep -q "zone example.org is ok"

# check conf
docker exec nsd nsd-checkconf /etc/nsd/nsd.conf

# keygen
docker exec nsd keygen example.org | grep -q "Generating ZSK & KSK keys for 'example.org'"
docker exec nsd [ -f /keys/Kexample.org.ksk.key ]
docker exec nsd [ -f /keys/Kexample.org.ksk.private ]
docker exec nsd [ -f /keys/Kexample.org.zsk.key ]
docker exec nsd [ -f /keys/Kexample.org.zsk.private ]

# signzone
docker exec nsd signzone example.org 20200101
docker exec nsd signzone example.org

# updateserial
docker exec nsd updateserial example.org

# dig
dig example.org @$CONTAINER_IP

echo "All tests passed"
