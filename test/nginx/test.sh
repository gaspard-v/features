#!/bin/bash

set -eEuo pipefail

## test Nginx config
/usr/sbin/nginx -t
