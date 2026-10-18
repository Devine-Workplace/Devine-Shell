#!/usr/bin/env sh

cat ~/.local/state/devine/sequences.txt 2>/dev/null

exec "$@"
