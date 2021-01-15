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

# standalone-ha-configuration.cli
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


