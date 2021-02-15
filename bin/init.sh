#!/bin/sh


set -euo pipefail


echo "[$(date)] Starting init.sh..."

# Copy zones to RW dir (mainly useful when deployed on k8s)
if [ -d "/zones_configmap" ]
then
    for domain in $(ls /zones_configmap)
    do
        cp "/zones_configmap/$domain" /zones
        echo "$domain copied from configmap to /zones"
    done
else
    echo "/zones_configmap does not exist: ignored"
fi


# Sign zones
for domain in $(ls /zones)
do
    if [ -e "/keys/K$domain.ksk.private" ] && [ -e "/keys/K$domain.zsk.private" ]
    then
        signzone "$domain"
    else
        echo "Missing /keys/K$domain.ksk.private or /keys/K$domain.zsk.private for $domain: not signed"
    fi
done

echo "[$(date)] init.sh done"


exit 0
