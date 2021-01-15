# build-keycloak.sh
#!/bin/bash -e

## Build/download Keycloak
```
if [ "$GIT_REPO" != "" ]; then
    if [ "$GIT_BRANCH" == "" ]; then
        GIT_BRANCH="master"
    fi

    # Install Git
    microdnf install -y git

    # Install Maven
    cd /opt/jboss 
    curl -s https://apache.uib.no/maven/maven-3/3.5.4/binaries/apache-maven-3.5.4-bin.tar.gz | tar xz
    mv apache-maven-3.5.4 /opt/jboss/maven
    export M2_HOME=/opt/jboss/maven

    # Clone repository
    git clone --depth 1 https://github.com/$GIT_REPO.git -b $GIT_BRANCH /opt/jboss/keycloak-source

    # Build
    cd /opt/jboss/keycloak-source

    MASTER_HEAD=`git log -n1 --format="%H"`
    echo "Keycloak from [build]: $GIT_REPO/$GIT_BRANCH/commit/$MASTER_HEAD"

    $M2_HOME/bin/mvn -Pdistribution -pl distribution/server-dist -am -Dmaven.test.skip clean install
    
    cd /opt/jboss

    tar xfz /opt/jboss/keycloak-source/distribution/server-dist/target/keycloak-*.tar.gz

    # Remove temporary files
    rm -rf /opt/jboss/maven
    rm -rf /opt/jboss/keycloak-source
    rm -rf $HOME/.m2/repository
    
    mv /opt/jboss/keycloak-* /opt/jboss/keycloak
else
    echo "Keycloak from [download]: $KEYCLOAK_DIST"

    cd /opt/jboss/
    curl -L $KEYCLOAK_DIST | tar zx
    mv /opt/jboss/keycloak-* /opt/jboss/keycloak
fi
```
##  Create DB modules
```
mkdir -p /opt/jboss/keycloak/modules/system/layers/base/org/postgresql/jdbc/main
cd /opt/jboss/keycloak/modules/system/layers/base/org/postgresql/jdbc/main
curl -L https://repo1.maven.org/maven2/org/postgresql/postgresql/$JDBC_POSTGRES_VERSION/postgresql-$JDBC_POSTGRES_VERSION.jar > postgres-jdbc.jar
cp /opt/jboss/tools/databases/postgres/module.xml .
```
## Configure Keycloak 
```
cd /opt/jboss/keycloak

bin/jboss-cli.sh --file=/opt/jboss/tools/cli/standalone-configuration.cli
rm -rf /opt/jboss/keycloak/standalone/configuration/standalone_xml_history

bin/jboss-cli.sh --file=/opt/jboss/tools/cli/standalone-ha-configuration.cli
rm -rf /opt/jboss/keycloak/standalone/configuration/standalone_xml_history
```
## Garbage 
```
rm -rf /opt/jboss/keycloak/standalone/tmp/auth
rm -rf /opt/jboss/keycloak/domain/tmp/auth
```
## Set permissions 
```
echo "jboss:x:0:root" >> /etc/group
echo "jboss:x:1000:0:JBoss user:/opt/jboss:/sbin/nologin" >> /etc/passwd
chown -R jboss:root /opt/jboss
chmod -R g+rwX /opt/jboss
```

## standalone-ha-configuration.cli
```
embed-server --server-config=standalone-ha.xml --std-out=echo
run-batch --file=/opt/jboss/tools/cli/loglevel.cli
run-batch --file=/opt/jboss/tools/cli/proxy.cli
run-batch --file=/opt/jboss/tools/cli/hostname.cli
run-batch --file=/opt/jboss/tools/cli/theme.cli
stop-embedded-server
```
# loglevel.cli
```
/subsystem=logging/logger=org.keycloak:add
/subsystem=logging/logger=org.keycloak:write-attribute(name=level,value=${env.KEYCLOAK_LOGLEVEL:INFO})

/subsystem=logging/root-logger=ROOT:change-root-log-level(level=${env.ROOT_LOGLEVEL:INFO})

/subsystem=logging/root-logger=ROOT:remove-handler(name="FILE")
/subsystem=logging/periodic-rotating-file-handler=FILE:remove

/subsystem=logging/console-handler=CONSOLE:undefine-attribute(name=level)
```
# proxy.cli
```
/subsystem=undertow/server=default-server/http-listener=default: write-attribute(name=proxy-address-forwarding, value=${env.PROXY_ADDRESS_FORWARDING:false})
/subsystem=undertow/server=default-server/https-listener=https: write-attribute(name=proxy-address-forwarding, value=${env.PROXY_ADDRESS_FORWARDING:false})
```

# hostname.cli
```
/subsystem=keycloak-server/spi=hostname:write-attribute(name=default-provider, value="${keycloak.hostname.provider:default}")
/subsystem=keycloak-server/spi=hostname/provider=fixed/:add(properties={hostname => "${keycloak.hostname.fixed.hostname:localhost}",httpPort => "${keycloak.hostname.fixed.httpPort:-1}",httpsPort => "${keycloak.hostname.fixed.httpsPort:-1}",alwaysHttps => "${keycloak.hostname.fixed.alwaysHttps:false}"},enabled=true)
```

# theme.cli
```
/subsystem=keycloak-server/theme=defaults:write-attribute(name=welcomeTheme,value=${env.KEYCLOAK_WELCOME_THEME:keycloak})
/subsystem=keycloak-server/theme=defaults:write-attribute(name=default,value=${env.KEYCLOAK_DEFAULT_THEME:keycloak})
```

# docker-entrypoint.sh
```
#!/bin/bash
set -eou pipefail

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
    local var="$1"
    local fileVar="${var}_FILE"
    local def="${2:-}"
    if [[ ${!var:-} && ${!fileVar:-} ]]; then
        echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
        exit 1
    fi
    local val="$def"
    if [[ ${!var:-} ]]; then
        val="${!var}"
    elif [[ ${!fileVar:-} ]]; then
        val="$(< "${!fileVar}")"
    fi

    if [[ -n $val ]]; then
        export "$var"="$val"
    fi

    unset "$fileVar"
}

SYS_PROPS=""

##################
# Add admin user #
##################

file_env 'KEYCLOAK_USER'
file_env 'KEYCLOAK_PASSWORD'

if [[ -n ${KEYCLOAK_USER:-} && -n ${KEYCLOAK_PASSWORD:-} ]]; then
    /opt/jboss/keycloak/bin/add-user-keycloak.sh --user "$KEYCLOAK_USER" --password "$KEYCLOAK_PASSWORD"
fi

############
# Hostname #
############

if [[ -n ${KEYCLOAK_FRONTEND_URL:-} ]]; then
    SYS_PROPS+="-Dkeycloak.frontendUrl=$KEYCLOAK_FRONTEND_URL"
fi

if [[ -n ${KEYCLOAK_HOSTNAME:-} ]]; then
    SYS_PROPS+=" -Dkeycloak.hostname.provider=fixed -Dkeycloak.hostname.fixed.hostname=$KEYCLOAK_HOSTNAME"

    if [[ -n ${KEYCLOAK_HTTP_PORT:-} ]]; then
        SYS_PROPS+=" -Dkeycloak.hostname.fixed.httpPort=$KEYCLOAK_HTTP_PORT"
    fi

    if [[ -n ${KEYCLOAK_HTTPS_PORT:-} ]]; then
        SYS_PROPS+=" -Dkeycloak.hostname.fixed.httpsPort=$KEYCLOAK_HTTPS_PORT"
    fi

    if [[ -n ${KEYCLOAK_ALWAYS_HTTPS:-} ]]; then
            SYS_PROPS+=" -Dkeycloak.hostname.fixed.alwaysHttps=$KEYCLOAK_ALWAYS_HTTPS"
    fi
fi

################
# Realm import #
################

if [[ -n ${KEYCLOAK_IMPORT:-} ]]; then
    SYS_PROPS+=" -Dkeycloak.import=$KEYCLOAK_IMPORT"
fi

########################
# JGroups bind options #
########################

if [[ -z ${BIND:-} ]]; then
    BIND=$(hostname --all-ip-addresses)
fi
if [[ -z ${BIND_OPTS:-} ]]; then
    for BIND_IP in $BIND
    do
        BIND_OPTS+=" -Djboss.bind.address=$BIND_IP -Djboss.bind.address.private=$BIND_IP "
    done
fi
SYS_PROPS+=" $BIND_OPTS"

#########################################
# Expose management console for metrics #
#########################################

if [[ -n ${KEYCLOAK_STATISTICS:-} ]] ; then
    SYS_PROPS+=" -Djboss.bind.address.management=0.0.0.0"
fi

#################
# Configuration #
#################

# If the server configuration parameter is not present, append the HA profile.
if echo "$@" | grep -E -v -- '-c |-c=|--server-config |--server-config='; then
    SYS_PROPS+=" -c=standalone-ha.xml"
fi

# Adding support for JAVA_OPTS_APPEND
sed -i '$a\\n# Append to JAVA_OPTS. Necessary to prevent some values being omitted if JAVA_OPTS is defined directly\nJAVA_OPTS=\"\$JAVA_OPTS \$JAVA_OPTS_APPEND\"' /opt/jboss/keycloak/bin/standalone.conf

############
# DB setup #
############

file_env 'DB_USER'
file_env 'DB_PASSWORD'
# Lower case DB_VENDOR
if [[ -n ${DB_VENDOR:-} ]]; then
  DB_VENDOR=$(echo "$DB_VENDOR" | tr "[:upper:]" "[:lower:]")
fi

# Detect DB vendor from default host names
if [[ -z ${DB_VENDOR:-} ]]; then
    if (getent hosts postgres &>/dev/null); then
        export DB_VENDOR="postgres"
    elif (getent hosts mysql &>/dev/null); then
        export DB_VENDOR="mysql"
    elif (getent hosts mariadb &>/dev/null); then
        export DB_VENDOR="mariadb"
    elif (getent hosts oracle &>/dev/null); then
        export DB_VENDOR="oracle"
    elif (getent hosts mssql &>/dev/null); then
        export DB_VENDOR="mssql"
    elif (getent hosts h2 &>/dev/null); then
        export DB_VENDOR="h2"
        export DB_ADDR="h2"
    fi
fi

# Detect DB vendor from legacy `*_ADDR` environment variables
if [[ -z ${DB_VENDOR:-} ]]; then
    if (printenv | grep '^POSTGRES_ADDR=' &>/dev/null); then
        export DB_VENDOR="postgres"
    elif (printenv | grep '^MYSQL_ADDR=' &>/dev/null); then
        export DB_VENDOR="mysql"
    elif (printenv | grep '^MARIADB_ADDR=' &>/dev/null); then
        export DB_VENDOR="mariadb"
    elif (printenv | grep '^ORACLE_ADDR=' &>/dev/null); then
        export DB_VENDOR="oracle"
    elif (printenv | grep '^MSSQL_ADDR=' &>/dev/null); then
        export DB_VENDOR="mssql"
    elif (printenv | grep '^H2_ADDR=' &>/dev/null); then
        export DB_VENDOR="h2"
        export DB_ADDR="h2"
    fi
fi

# Default to H2 if DB type not detected
if [[ -z ${DB_VENDOR:-} ]]; then
    export DB_VENDOR="h2"
fi

# if the DB_VENDOR is postgres then append port to the DB_ADDR
function append_port_db_addr() {
  local db_host_regex='^[a-zA-Z0-9]([a-zA-Z0-9]|-|.)*:[0-9]{4,5}$'
  IFS=',' read -ra addresses <<< "$DB_ADDR"
  DB_ADDR=""
  for i in "${addresses[@]}"; do
    if [[ $i =~ $db_host_regex ]]; then
        DB_ADDR+=$i;
    else
        DB_ADDR+="${i}:${DB_PORT}";
    fi
    DB_ADDR+=","
  done
  DB_ADDR=$(echo $DB_ADDR | sed 's/.$//') # remove the last comma
}
# Set DB name
case "$DB_VENDOR" in
    postgres)
        DB_NAME="PostgreSQL"
        if [[ -z ${DB_PORT:-} ]] ; then
          DB_PORT="5432"
        fi
        append_port_db_addr
        ;;
    mysql)
        DB_NAME="MySQL";;
    mariadb)
        DB_NAME="MariaDB";;
    mssql)
        DB_NAME="Microsoft SQL Server";;
    oracle)
        DB_NAME="Oracle";;
    h2)
        if [[ -z ${DB_ADDR:-} ]] ; then
          DB_NAME="Embedded H2"
        else
          DB_NAME="H2"
        fi;;
    *)
        echo "Unknown DB vendor $DB_VENDOR"
        exit 1
esac

if [ "$DB_VENDOR" != "mssql" ] && [ "$DB_VENDOR" != "h2" ]; then
    # Append '?' in the beginning of the string if JDBC_PARAMS value isn't empty
    JDBC_PARAMS=$(echo "${JDBC_PARAMS:-}" | sed '/^$/! s/^/?/')
else
    JDBC_PARAMS=${JDBC_PARAMS:-}
fi

export JDBC_PARAMS

# Convert deprecated DB specific variables
function set_legacy_vars() {
  local suffixes=(ADDR DATABASE USER PASSWORD PORT)
  for suffix in "${suffixes[@]}"; do
    local varname="$1_$suffix"
    if [[ -n ${!varname:-} ]]; then
      echo WARNING: "$varname" variable name is DEPRECATED replace with DB_"$suffix"
      export DB_"$suffix=${!varname}"
    fi
  done
}
set_legacy_vars "$(echo "$DB_VENDOR" | tr "[:upper:]" "[:lower:]")"

# Configure DB

echo "========================================================================="
echo ""
echo "  Using $DB_NAME database"
echo ""
echo "========================================================================="
echo ""

configured_file="/opt/jboss/configured"
if [ ! -e "$configured_file" ]; then
    touch "$configured_file"

    if [ "$DB_NAME" != "Embedded H2" ]; then
      /bin/sh /opt/jboss/tools/databases/change-database.sh $DB_VENDOR
    fi
	
    /opt/jboss/tools/x509.sh
    /opt/jboss/tools/jgroups.sh
    /opt/jboss/tools/infinispan.sh
    /opt/jboss/tools/statistics.sh
    /opt/jboss/tools/vault.sh
    /opt/jboss/tools/autorun.sh
fi

##################
# Start Keycloak #
##################

exec /opt/jboss/keycloak/bin/standalone.sh $SYS_PROPS $@
exit $?
```

##/opt/jboss/tools/x509.sh
```
#!/bin/bash

function autogenerate_keystores() {
  # Keystore infix notation as used in templates to keystore name mapping
  declare -A KEYSTORES=( ["https"]="HTTPS" )

  local KEYSTORES_STORAGE="${JBOSS_HOME}/standalone/configuration/keystores"
  if [ ! -d "${KEYSTORES_STORAGE}" ]; then
    mkdir -p "${KEYSTORES_STORAGE}"
  fi

  # Auto-generate the HTTPS keystore if volumes for OpenShift's
  # serving x509 certificate secrets service were properly mounted
  for KEYSTORE_TYPE in "${!KEYSTORES[@]}"; do

    local X509_KEYSTORE_DIR="/etc/x509/${KEYSTORE_TYPE}"
    local X509_CRT="tls.crt"
    local X509_KEY="tls.key"
    local NAME="keycloak-${KEYSTORE_TYPE}-key"
    local PASSWORD=$(openssl rand -base64 32 2>/dev/null)
    local JKS_KEYSTORE_FILE="${KEYSTORE_TYPE}-keystore.jks"
    local PKCS12_KEYSTORE_FILE="${KEYSTORE_TYPE}-keystore.pk12"

    if [ -f "${X509_KEYSTORE_DIR}/${X509_KEY}" ] && [ -f "${X509_KEYSTORE_DIR}/${X509_CRT}" ]; then

      echo "Creating ${KEYSTORES[$KEYSTORE_TYPE]} keystore via OpenShift's service serving x509 certificate secrets.."

      openssl pkcs12 -export \
      -name "${NAME}" \
      -inkey "${X509_KEYSTORE_DIR}/${X509_KEY}" \
      -in "${X509_KEYSTORE_DIR}/${X509_CRT}" \
      -out "${KEYSTORES_STORAGE}/${PKCS12_KEYSTORE_FILE}" \
      -password pass:"${PASSWORD}" >& /dev/null

      keytool -importkeystore -noprompt \
      -srcalias "${NAME}" -destalias "${NAME}" \
      -srckeystore "${KEYSTORES_STORAGE}/${PKCS12_KEYSTORE_FILE}" \
      -srcstoretype pkcs12 \
      -destkeystore "${KEYSTORES_STORAGE}/${JKS_KEYSTORE_FILE}" \
      -storepass "${PASSWORD}" -srcstorepass "${PASSWORD}" >& /dev/null

      if [ -f "${KEYSTORES_STORAGE}/${JKS_KEYSTORE_FILE}" ]; then
        echo "${KEYSTORES[$KEYSTORE_TYPE]} keystore successfully created at: ${KEYSTORES_STORAGE}/${JKS_KEYSTORE_FILE}"
      else
        echo "${KEYSTORES[$KEYSTORE_TYPE]} keystore not created at: ${KEYSTORES_STORAGE}/${JKS_KEYSTORE_FILE} (check permissions?)"
      fi

      echo "set keycloak_tls_keystore_password=${PASSWORD}" >> "$JBOSS_HOME/bin/.jbossclirc"
      echo "set keycloak_tls_keystore_file=${KEYSTORES_STORAGE}/${JKS_KEYSTORE_FILE}" >> "$JBOSS_HOME/bin/.jbossclirc"
      echo "set configuration_file=standalone.xml" >> "$JBOSS_HOME/bin/.jbossclirc"
      $JBOSS_HOME/bin/jboss-cli.sh --file=/opt/jboss/tools/cli/x509-keystore.cli >& /dev/null
      sed -i '$ d' "$JBOSS_HOME/bin/.jbossclirc"
      echo "set configuration_file=standalone-ha.xml" >> "$JBOSS_HOME/bin/.jbossclirc"
      $JBOSS_HOME/bin/jboss-cli.sh --file=/opt/jboss/tools/cli/x509-keystore.cli >& /dev/null
      sed -i '$ d' "$JBOSS_HOME/bin/.jbossclirc"
    fi

  done

  # Auto-generate the Keycloak truststore if X509_CA_BUNDLE was provided
  local -r X509_CRT_DELIMITER="/-----BEGIN CERTIFICATE-----/"
  local JKS_TRUSTSTORE_FILE="truststore.jks"
  local JKS_TRUSTSTORE_PATH="${KEYSTORES_STORAGE}/${JKS_TRUSTSTORE_FILE}"
  local PASSWORD=$(openssl rand -base64 32 2>/dev/null)
  local TEMPORARY_CERTIFICATE="temporary_ca.crt"
  if [ -n "${X509_CA_BUNDLE}" ]; then
    pushd /tmp >& /dev/null
    echo "Creating Keycloak truststore.."
    # We use cat here, so that users could specify multiple CA Bundles using space or even wildcard:
    # X509_CA_BUNDLE=/var/run/secrets/kubernetes.io/serviceaccount/*.crt
    # Note, that there is no quotes here, that's intentional. Once can use spaces in the $X509_CA_BUNDLE like this:
    # X509_CA_BUNDLE=/ca.crt /ca2.crt
    cat ${X509_CA_BUNDLE} > ${TEMPORARY_CERTIFICATE}
    csplit -s -z -f crt- "${TEMPORARY_CERTIFICATE}" "${X509_CRT_DELIMITER}" '{*}'
    for CERT_FILE in crt-*; do
      keytool -import -noprompt -keystore "${JKS_TRUSTSTORE_PATH}" -file "${CERT_FILE}" \
      -storepass "${PASSWORD}" -alias "service-${CERT_FILE}" >& /dev/null
    done

    if [ -f "${JKS_TRUSTSTORE_PATH}" ]; then
      echo "Keycloak truststore successfully created at: ${JKS_TRUSTSTORE_PATH}"
    else
      echo "Keycloak truststore not created at: ${JKS_TRUSTSTORE_PATH}"
    fi

    # Import existing system CA certificates into the newly generated truststore
    local SYSTEM_CACERTS=$(readlink -e $(dirname $(readlink -e $(which keytool)))"/../lib/security/cacerts")
    if keytool -v -list -keystore "${SYSTEM_CACERTS}" -storepass "changeit" > /dev/null; then
      echo "Importing certificates from system's Java CA certificate bundle into Keycloak truststore.."
      keytool -importkeystore -noprompt \
      -srckeystore "${SYSTEM_CACERTS}" \
      -destkeystore "${JKS_TRUSTSTORE_PATH}" \
      -srcstoretype jks -deststoretype jks \
      -storepass "${PASSWORD}" -srcstorepass "changeit" >& /dev/null
      if [ "$?" -eq "0" ]; then
        echo "Successfully imported certificates from system's Java CA certificate bundle into Keycloak truststore at: ${JKS_TRUSTSTORE_PATH}"
      else
        echo "Failed to import certificates from system's Java CA certificate bundle into Keycloak truststore!"
      fi
    fi

    echo "set keycloak_tls_truststore_password=${PASSWORD}" >> "$JBOSS_HOME/bin/.jbossclirc"
    echo "set keycloak_tls_truststore_file=${KEYSTORES_STORAGE}/${JKS_TRUSTSTORE_FILE}" >> "$JBOSS_HOME/bin/.jbossclirc"
    echo "set configuration_file=standalone.xml" >> "$JBOSS_HOME/bin/.jbossclirc"
    $JBOSS_HOME/bin/jboss-cli.sh --file=/opt/jboss/tools/cli/x509-truststore.cli >& /dev/null
    sed -i '$ d' "$JBOSS_HOME/bin/.jbossclirc"
    echo "set configuration_file=standalone-ha.xml" >> "$JBOSS_HOME/bin/.jbossclirc"
    $JBOSS_HOME/bin/jboss-cli.sh --file=/opt/jboss/tools/cli/x509-truststore.cli >& /dev/null
    sed -i '$ d' "$JBOSS_HOME/bin/.jbossclirc"

    popd >& /dev/null
  fi
}

autogenerate_keystores
```

##/opt/jboss/tools/jgroups.sh
```
#!/bin/bash

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

    echo "Setting JGroups discovery to $JGROUPS_DISCOVERY_PROTOCOL with properties $JGROUPS_DISCOVERY_PROPERTIES_PARSED"
    echo "set keycloak_jgroups_discovery_protocol=${JGROUPS_DISCOVERY_PROTOCOL}" >> "$JBOSS_HOME/bin/.jbossclirc"
    echo "set keycloak_jgroups_discovery_protocol_properties=${JGROUPS_DISCOVERY_PROPERTIES_PARSED}" >> "$JBOSS_HOME/bin/.jbossclirc"
    echo "set keycloak_jgroups_transport_stack=${JGROUPS_TRANSPORT_STACK:-tcp}" >> "$JBOSS_HOME/bin/.jbossclirc"
    # If there's a specific CLI file for given protocol - execute it. If not, we should be good with the default one.
    if [ -f "/opt/jboss/tools/cli/jgroups/discovery/$JGROUPS_DISCOVERY_PROTOCOL.cli" ]; then
       $JBOSS_HOME/bin/jboss-cli.sh --file="/opt/jboss/tools/cli/jgroups/discovery/$JGROUPS_DISCOVERY_PROTOCOL.cli" >& /dev/null
    else
       $JBOSS_HOME/bin/jboss-cli.sh --file="/opt/jboss/tools/cli/jgroups/discovery/default.cli" >& /dev/null
    fi
fi
```

##/opt/jboss/tools/infinispan.sh
```
# How many owners / replicas should our distributed caches have. If <2 any node that is removed from the cluster will cause a data-loss!
# As it is only sensible to replicate AuthenticationSessions for certain cases, their replication factor can be configured independently

if [ -n "$CACHE_OWNERS_COUNT" ]; then
    echo "Setting cache owners to $CACHE_OWNERS_COUNT replicas"

    # Check and log the replication factor of AuthenticationSessions, otherwise this is set to 1 by default
    if [ -n "$CACHE_OWNERS_AUTH_SESSIONS_COUNT" ]; then
        echo "Enabling replication of AuthenticationSessions with ${CACHE_OWNERS_AUTH_SESSIONS_COUNT} replicas"
    else
        echo "AuthenticationSessions will NOT be replicated, set CACHE_OWNERS_AUTH_SESSIONS_COUNT to configure this"
    fi
$JBOSS_HOME/bin/jboss-cli.sh --file="/opt/jboss/tools/cli/infinispan/cache-owners.cli" >& /dev/null
fi
```

##/opt/jboss/tools/statistics.sh
```
#!/bin/bash

if [ -n "$KEYCLOAK_STATISTICS" ]; then
   IFS=',' read -ra metrics <<< "$KEYCLOAK_STATISTICS"
   for file in /opt/jboss/tools/cli/metrics/*.cli; do
      name=${file##*/}
      base=${name%.cli}
      if [[  $KEYCLOAK_STATISTICS == *"$base"* ]] || [[  $KEYCLOAK_STATISTICS == *"all"* ]];  then
         $JBOSS_HOME/bin/jboss-cli.sh --file="$file" >& /dev/null
      fi
   done
fi
```

##/opt/jboss/tools/vault.sh
```
#!/bin/bash

if [ -d "$JBOSS_HOME/secrets" ]; then
    echo "set plaintext_vault_provider_dir=${JBOSS_HOME}/secrets" >> "$JBOSS_HOME/bin/.jbossclirc"

    echo "set configuration_file=standalone.xml" >> "$JBOSS_HOME/bin/.jbossclirc"
    $JBOSS_HOME/bin/jboss-cli.sh --file=/opt/jboss/tools/cli/files-plaintext-vault.cli
    sed -i '$ d' "$JBOSS_HOME/bin/.jbossclirc"

    echo "set configuration_file=standalone-ha.xml" >> "$JBOSS_HOME/bin/.jbossclirc"
    $JBOSS_HOME/bin/jboss-cli.sh --file=/opt/jboss/tools/cli/files-plaintext-vault.cli
    sed -i '$ d' "$JBOSS_HOME/bin/.jbossclirc"
fi
```
##/opt/jboss/tools/autorun.sh
 ```
 #!/bin/bash -e
cd /opt/jboss/keycloak

ENTRYPOINT_DIR=/opt/jboss/startup-scripts

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
 ```
