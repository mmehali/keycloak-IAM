#!/bin/bash

if [ -n "$KEYCLOAK_STATISTICS" ]; then
   IFS=',' read -ra metrics <<< "$KEYCLOAK_STATISTICS"
   for file in /opt/jboss/tools/cli/metrics/*.cli; do
      name=${file##*/}
      base=${name%.cli}
      if [[  $KEYCLOAK_STATISTICS == *"$base"* ]] || [[  $KEYCLOAK_STATISTICS == *"all"* ]];  then
         $JBOSS_HOME/bin/jboss-cli.sh --file="$file"  --properties=env.properties >& /dev/null
      fi
   done
fi
