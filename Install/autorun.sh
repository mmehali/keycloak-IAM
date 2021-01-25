#!/bin/bash -e
cd /opt/keycloak

ENTRYPOINT_DIR=/opt/keycloak/startup-scripts

if [[ -d "$ENTRYPOINT_DIR" ]]; then
  # First run cli autoruns
  for f in "$ENTRYPOINT_DIR"/*; do
    if [[ "$f" == *.cli ]]; then
      echo "Executing cli script: $f"
      bin/jboss-cli.sh --file="$f"
    elif [[ -x "$f" ]]; then
      echo "Executing: $f"
      "$f"
    else
      echo "Ignoring file in $ENTRYPOINT_DIR (not *.cli or executable): $f"
    fi
  done
fi
