#!/bin/bash -e

STARTUP_SCRIPTS_DIR=/opt/keycloak/startup-scripts

if [[ -d "$STARTUP_SCRIPTS_DIR" ]]; then
  for f in "$STARTUP_SCRIPTS_DIR"/*; do
    if [[ "$f" == *.cli ]]; then
      echo "Executer le script cli : $f"
      /opt/keycloak/bin/jboss-cli.sh --file="$f"  --properties=env.properties
    elif [[ -x "$f" ]]; then
      echo "Executer le script: $f"
      "$f"
    else
      echo "Ignorer le fichier $STARTUP_SCRIPTS_DIR (not *.cli or executable): $f"
    fi
  done
fi
