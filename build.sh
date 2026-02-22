#!/bin/bash

set -e

ARCH=$(uname -m)

if [[ "$ARCH" != x86* ]]; then
    echo "cannot build android on $ARCH"
    exit 0
fi

echo "current arch: $ARCH"
