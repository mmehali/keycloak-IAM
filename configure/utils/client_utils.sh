#!/usr/bin/env bash

set -euo pipefail

# creation d'un nouveau client et l'activé.
# le client n'est creer que s'il n'exite pas.
createClient() {
    # arguments
    REALM_NAME=$1
    CLIENT_ID=$2
    #
    ID=$(getClient $REALM_NAME $CLIENT_ID)
    if [[ "$ID" == "" ]]; then
        $KCADM create clients -r $REALM_NAME -s clientId=$CLIENT_ID -s enabled=true
    fi
    echo $(getClient $REALM_NAME $CLIENT_ID)
}

# Extraire l'id du client en fontion du clientID
getClient () {
    # arguments
    REALM_NAME=$1
    CLIENT_ID=$2
    #
    ID=$($KCADM get clients -r $REALM_NAME --fields id,clientId | jq '.[] | select(.clientId==("'$CLIENT_ID'")) | .id')
    echo $(sed -e 's/"//g' <<< $ID)
}

