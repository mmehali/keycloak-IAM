#!/usr/bin/env bash

set -euo pipefail

# creation d'un nouveau realm et l'activé.
# le realm n'est creer que s'il n'exite pas.
createRealm() {
  # arguments
  REALM_NAME=$1
  
  REALM_EXIST=$($KCADM get realms/$REALM_NAME)
  if [ "$REALM_EXIST" == "" ]; then
    $KCADM create realms -s realm="${REALM_NAME}" -s enabled=true
  fi
}

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
