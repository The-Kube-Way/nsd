#!/bin/bash

set -e
set -x

shellcheck bin/* test/*.sh

hadolint Dockerfile
