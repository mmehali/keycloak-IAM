#!/usr/bin/env bash

set -euo pipefail

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
