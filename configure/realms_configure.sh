#!/usr/bin/env bash

set -euo pipefail

echo "----------------------------------------------"
echo "               Configuration des realms       "
echo "----------------------------------------------"

source $BASEDIR/realm_master.sh
source $BASEDIR/realm_myrealm.sh
