#!/usr/bin/env bash

set -euo pipefail


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
