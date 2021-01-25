echo "Configuration du cache owners à 2 replicas"
echo "Activation de la replication sur le cache AuthenticationSessions avec 2 replicas"
/opt/keycloak/bin/jboss-cli.sh --file="/vagrant/cli/infinispan/cache-owners.cli"

#Test : pour tester commenter le haut
#~/DEV/Keycloak/slave/bin/jboss-cli.sh --file="./cli/infinispan/cache-owners.cli"
