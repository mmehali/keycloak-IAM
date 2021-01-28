#!/usr/bin/env bash

set -euo pipefail

# Creation d'un utilisateur avec un username s'il n'existe pas et retourrne son id.
createUser() {
    # arguments
    REALM_NAME=$1
    USER_NAME=$2
    #
    USER_ID=$(getUser $REALM_NAME $USER_NAME)
    if [ "$USER_ID" == "" ]; then
        $KCADM create users -r $REALM_NAME -s username=$USER_NAME -s enabled=true
    fi
    echo $(getUser $REALM_NAME $USER_NAME)
}

# Reourne l'ID d'un utilisateur en fonction de son username
getUser() {
    # arguments
    REALM_NAME=$1
    USERNAME=$2
    #
    USER=$($KCADM get users -r $REALM_NAME -q username=$USERNAME | jq '.[] | select(.username==("'$USERNAME'")) | .id' )
    echo $(sed -e 's/"//g' <<< $USER)
}
