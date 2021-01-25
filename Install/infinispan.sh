echo "Setting cache owners to 2 replicas"
echo "Enabling replication of AuthenticationSessions with 2 replicas"
/opt/keycloak/bin/jboss-cli.sh --file="/vagrant/cli/infinispan/cache-owners.cli"

#Test : pour tester commenter le haut
#~/DEV/Keycloak/slave/bin/jboss-cli.sh --file="./cli/infinispan/cache-owners.cli"
