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



# create a top level flow for the given alias if it doesn't exist yet and return the object id
createTopLevelFlow() {
    # arguments
    REALM_NAME=$1
    ALIAS=$2
    #
    FLOW_ID=$(getTopLevelFlow "$REALM_NAME" "$ALIAS")
    if [ "$FLOW_ID" == "" ]; then
        $KCADM create authentication/flows -r "$REALM_NAME" -s alias="$ALIAS" -s providerId=basic-flow -s topLevel=true -s builtIn=false
    fi
    echo $(getTopLevelFlow "$REALM_NAME" "$ALIAS")
}

deleteTopLevelFlow() {
    # arguments
    REALM_NAME=$1
    ALIAS=$2
    #
    FLOW_ID=$(getTopLevelFlow "$REALM_NAME" "$ALIAS")
    if [ "$FLOW_ID" != "" ]; then
        $KCADM delete authentication/flows/"$FLOW_ID" -r "$REALM_NAME"
    fi
    echo $(getTopLevelFlow "$REALM_NAME" "$ALIAS")
}

getTopLevelFlow() {
    # arguments
    REALM_NAME=$1
    ALIAS=$2
    #
    ID=$($KCADM get authentication/flows -r "$REALM_NAME" --fields id,alias| jq '.[] | select(.alias==("'$ALIAS'")) | .id')
    echo $(sed -e 's/"//g' <<< $ID)
}

# create a new execution for a given providerId (the providerId is defined by AuthenticatorFactory)
createExecution() {
    # arguments
    REALM_NAME=$1
    FLOW=$2
    PROVIDER=$3
    REQUIREMENT=$4
    #
    EXECUTION_ID=$($KCADM create authentication/flows/"$FLOW"/executions/execution -i -b '{"provider" : "'"$PROVIDER"'"}' -r "$REALM_NAME")
    $KCADM update authentication/flows/"$FLOW"/executions -b '{"id":"'"$EXECUTION_ID"'","requirement":"'"$REQUIREMENT"'"}' -r "$REALM_NAME"
}

# create a new subflow
createSubflow() {
    # arguments
    REALM_NAME=$1
    TOPLEVEL=$2
    PARENT=$3
    ALIAS="$4"
    REQUIREMENT=$5
    #
    FLOW_ID=$($KCADM create authentication/flows/"$PARENT"/executions/flow -i -r "$REALM_NAME" -b '{"alias" : "'"$ALIAS"'" , "type" : "basic-flow"}')
    EXECUTION_ID=$(getFlowExecution "$REALM_NAME" "$TOPLEVEL" "$FLOW_ID")
    $KCADM update authentication/flows/"$TOPLEVEL"/executions -r "$REALM_NAME" -b '{"id":"'"$EXECUTION_ID"'","requirement":"'"$REQUIREMENT"'"}'
    echo "Created new subflow with id '$FLOW_ID', alias '"$ALIAS"'"
}

getFlowExecution() {
    # arguments
    REALM_NAME=$1
    TOPLEVEL=$2
    FLOW_ID=$3
    #
    ID=$($KCADM get authentication/flows/"$TOPLEVEL"/executions -r "$REALM_NAME" --fields id,flowId,alias | jq '.[] | select(.flowId==("'"$FLOW_ID"'")) | .id')
    echo $(sed -e 's/"//g' <<< $ID)
}

registerRequiredAction() {
    #arguments
    REALM_NAME="$1"
    PROVIDER_ID="$2"
    NAME="$3"

    $KCADM delete authentication/required-actions/"$PROVIDER_ID" -r "$REALM_NAME"
    $KCADM create authentication/register-required-action -r "$REALM_NAME" -s providerId="$PROVIDER_ID" -s name="$NAME"
}

# get the id of the identityProvider with the given alias
getIdentityProvider () {
    # arguments
    REALM=$1
    IDP_ALIAS=$2
    #
    ID=$($KCADM get identity-provider/instances -r $REALM --fields alias,internalId | jq '.[] | select(.alias==("'$IDP_ALIAS'")) | .internalId')
    echo $(sed -e 's/"//g' <<< $ID)
}

createIdentityProvider() {
    # arguments
    REALM_NAME=$1
    ALIAS=$2
    NAME=$3
    PROVIDER_ID=$4
    #
    IDENTITY_PROVIDER_ID=$(getIdentityProvider $REALM_NAME $ALIAS)
    if [ "$IDENTITY_PROVIDER_ID" == "" ]; then
        $KCADM create identity-provider/instances -r $REALM_NAME -s alias=$ALIAS -s displayName="$NAME" -s providerId=$PROVIDER_ID
    fi
    echo $(getIdentityProvider $REALM_NAME $ALIAS)
}

deleteIdentityProvider() {
    # arguments
    REALM_NAME=$1
    ALIAS=$2
    #
    IDENTITY_PROVIDER_ID=$(getIdentityProvider $REALM_NAME $ALIAS)
    if [ "$IDENTITY_PROVIDER_ID" != "" ]; then
        $KCADM delete identity-provider/instances/$IDENTITY_PROVIDER_ID -r $REALM_NAME
    fi
}

getIdentityProviderMapper() {
    # arguments
    REALM_NAME=$1
    IDENTITY_PROVIDER_ALIAS=$2
    MAPPER_NAME="${3}"
    #
    ID=$($KCADM get identity-provider/instances/$IDENTITY_PROVIDER_ALIAS/mappers -r $REALM_NAME --fields id,name | jq '.[] | select(.name==("'"${MAPPER_NAME}"'")) | .id')
    echo $(sed -e 's/"//g' <<< $ID)
}

createIdentityProviderMapper() {
    # arguments
    REALM_NAME=$1
    IDENTITY_PROVIDER_ALIAS=$2
    MAPPER_NAME="${3}"
    MAPPER_ID=$4
    #
    IDENTITY_PROVIDER_MAPPER_ID=$(getIdentityProviderMapper $REALM_NAME $IDENTITY_PROVIDER_ALIAS "${MAPPER_NAME}")
    if [ "$IDENTITY_PROVIDER_MAPPER_ID" == "" ]; then
        $KCADM create identity-provider/instances/$IDENTITY_PROVIDER_ALIAS/mappers -r $REALM_NAME -s identityProviderAlias=$IDENTITY_PROVIDER_ALIAS -s name="${MAPPER_NAME}" -s identityProviderMapper=$MAPPER_ID
    fi
    echo $(getIdentityProviderMapper $REALM_NAME $IDENTITY_PROVIDER_ALIAS "${MAPPER_NAME}")
}

getExecution() {
    #arguments
    REALM=$1
    FLOW_ID=$2
    PROVIDER_ID=$3
    #
    EXECUTION_ID=$($KCADM get authentication/flows/$FLOW_ID/executions -r $REALM --fields providerId,id | jq '.[] | select(.providerId==("'$PROVIDER_ID'")) |.id')
    echo $(sed -e 's/"//g' <<< $EXECUTION_ID)
}

createIdentityProviderRedirectorConfig() {
    #arguments
    REALM_NAME=$1
    EXECUTION_ID=$2
    #
}
