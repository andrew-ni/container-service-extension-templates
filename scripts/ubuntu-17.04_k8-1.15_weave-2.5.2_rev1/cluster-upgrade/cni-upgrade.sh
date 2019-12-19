#!/usr/bin/env bash

set -e

weave reset
rm /opt/cni/bin/weave-*
curl -L git.io/weave -o /usr/local/bin/weave
chmod a+x /usr/local/bin/weave
