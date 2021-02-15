#!/bin/sh

set -eux

# Declare variables to be compilant with shellcheck
UID=$UID
GID=$GID

chown -R "$UID":"$GID" /var/db/nsd /tmp

exec /sbin/tini -- nsd -u "$UID.$GID" -P /tmp/nsd.pid -d
