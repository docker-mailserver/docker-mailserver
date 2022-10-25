#!/bin/bash

# This user patches script runs right before starting the daemons.
# That means, all the other configuration is in place, so the script
# can make final adjustments.
# If you modify any supervisord configuration, make sure to run
# "supervisorctl update" or "supervisorctl reload" afterwards.

# For more information, see
# https://docker-mailserver.github.io/docker-mailserver/edge/config/advanced/override-defaults/user-patches/

echo 'user-patches.sh successfully executed'
