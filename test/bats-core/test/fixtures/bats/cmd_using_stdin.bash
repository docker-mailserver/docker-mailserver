#!/usr/bin/env bash

# Fractional timeout supported in bash 4+
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
  timeout=1
else
  timeout=0.01
fi

# Just reading from stdin
while read -r -t $timeout foo; do
  if [ "$foo" == "EXIT" ]; then
    echo "Found"
    exit 0
  fi
done

echo "Not found"
exit 1
