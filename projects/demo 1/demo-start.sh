#!/usr/bin/env bash
echo "CIC Demo 1: Starting bettercap..."
pushd /home/attacker || exit 1
if sudo bettercap -caplet ./step1.cap; then
    echo "OK..."
fi