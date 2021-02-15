#!/bin/bash

set -e
set -x

docker container stop nsd || true
docker container rm --volumes nsd || true
