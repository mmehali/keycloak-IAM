#!/usr/bin/env bash

set -euo pipefail

echo "--------------------------------------------------------"
echo "        Configuration keycloak                          "
echo "--------------------------------------------------------"

BASEDIR=$(dirname "$0")
source $BASEDIR/keycloak-utils.sh

if [ "$KCADM" == "" ]; then
    KCADM=$KEYCLOAK_HOME/bin/kcadm.sh
    echo "Using $KCADM as the admin CLI."
fi

$KCADM config credentials --server http://$HOST_FOR_KCADM:8080/auth --user $KEYCLOAK_USER --password $KEYCLOAK_PASSWORD --realm master

source $BASEDIR/realms.sh

