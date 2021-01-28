
echo "Configuration du cache owners à 2 replicas"
echo "Activation de la replication sur le cache AuthenticationSessions avec 2 replicas"
/opt/keycloak/bin/jboss-cli.sh --file="${INSTALL_SRC}/cli/infinispan/cache-owners.cli"  --properties=env.properties

#Test : pour tester commenter le haut
#~/DEV/Keycloak/slave/bin/jboss-cli.sh --file="./cli/infinispan/cache-owners.cli" --properties=env.properties
