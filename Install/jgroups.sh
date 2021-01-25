#!/usr/bin/env bash

JGROUPS_DISCOVERY_EXTERNAL_IP=172.21.48.39
JGROUPS_DISCOVERY_PROTOCOL=TCPPING
JGROUPS_DISCOVERY_PROPERTIES=initial_hosts="172.21.48.4[7600],172.21.48.39[7600]"

# If JGROUPS_DISCOVERY_PROPERTIES is set, it must be in the following format: PROP1=FOO,PROP2=BAR
# If JGROUPS_DISCOVERY_PROPERTIES_DIRECT is set, it must be in the following format: {PROP1=>FOO,PROP2=>BAR}
# It's a configuration error to set both of these variables

if [ -n "$JGROUPS_DISCOVERY_PROTOCOL" ]; then
    if [ -n "$JGROUPS_DISCOVERY_PROPERTIES" ] && [ -n "$JGROUPS_DISCOVERY_PROPERTIES_DIRECT" ]; then
       echo >&2 "error: both JGROUPS_DISCOVERY_PROPERTIES and JGROUPS_DISCOVERY_PROPERTIES_DIRECT are set (but are exclusive)"
       exit 1
    fi

    if [ -n "$JGROUPS_DISCOVERY_PROPERTIES_DIRECT" ]; then
       JGROUPS_DISCOVERY_PROPERTIES_PARSED="$JGROUPS_DISCOVERY_PROPERTIES_DIRECT"
    else
       JGROUPS_DISCOVERY_PROPERTIES_PARSED=`echo $JGROUPS_DISCOVERY_PROPERTIES | sed "s/=/=>/g"`
       JGROUPS_DISCOVERY_PROPERTIES_PARSED="{$JGROUPS_DISCOVERY_PROPERTIES_PARSED}"
    fi


    echo "10.2.1 : Ajouter le parametres jgroups ci-dessous a /opt/keycloak/bin/.jbossclirc"
    echo "set keycloak_jgroups_discovery_protocol=${JGROUPS_DISCOVERY_PROTOCOL}" 
    echo "set keycloak_jgroups_discovery_protocol_properties=${JGROUPS_DISCOVERY_PROPERTIES_PARSED}"
    echo "set keycloak_jgroups_transport_stack=${JGROUPS_TRANSPORT_STACK:-tcp}"
    
    echo "Setting JGroups discovery to $JGROUPS_DISCOVERY_PROTOCOL with properties $JGROUPS_DISCOVERY_PROPERTIES_PARSED"
    echo "set keycloak_jgroups_discovery_protocol=${JGROUPS_DISCOVERY_PROTOCOL}" >> "/opt/keycloak/bin/.jbossclirc"
    echo "set keycloak_jgroups_discovery_protocol_properties=${JGROUPS_DISCOVERY_PROPERTIES_PARSED}" >> "/opt/keycloak/bin/.jbossclirc"
    echo "set keycloak_jgroups_transport_stack=${JGROUPS_TRANSPORT_STACK:-tcp}" >> "/opt/keycloak/bin/.jbossclirc"

    
    
    #if there's a specific CLI file for given protocol - execute it. If not, we should be good with the default one.
    if [ -f "/vagrant/cli/jgroups/discovery/$JGROUPS_DISCOVERY_PROTOCOL.cli" ]; then
       echo "10.2.1 : /opt/keycloak/bin/jboss-cli.sh --file="/vagrant/cli/jgroups/discovery/$JGROUPS_DISCOVERY_PROTOCOL.cli" 
       sudo /opt/keycloak/bin/jboss-cli.sh --file="/vagrant/cli/jgroups/discovery/$JGROUPS_DISCOVERY_PROTOCOL.cli" >& /dev/null
    else
       echo "10.2.1 :/opt/bin/jboss-cli.sh --file="/vargrant/cli/jgroups/discovery/default.cli"
       sudo /opt/keycloak/bin/jboss-cli.sh --file="/vargrant/cli/jgroups/discovery/default.cli" >& /dev/null
    fi
fi
