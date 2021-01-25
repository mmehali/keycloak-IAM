#!/bin/bash

if [ -d "/opt/keycloak/secrets" ]; then
    echo "set plaintext_vault_provider_dir=/opt/keycloak/secrets" >> "/opt/keycloak/bin/.jbossclirc"

    echo "set configuration_file=standalone-ha.xml" >> "/opt/keycloak/bin/.jbossclirc"
    /opt/keycloak/bin/jboss-cli.sh --file=/vagrant/cli/files-plaintext-vault.cli
    sed -i '$ d' "/opt/keycloak/bin/.jbossclirc"
fi
