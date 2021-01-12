#!/bin/bash
#title           :keycloak-install.sh
#description     :The script to install Keycloak
#more            :http://sukharevd.net/wildfly-8-installation.html
#author	         :Dmitriy Sukharev
#date            :20160701
#usage           :/bin/bash keycloak-install.sh

# This is based on the great wildfly-install.sh by Dmitriy Sukharev at https://gist.github.com/sukharevd/6087988

KEYCLOAK_VERSION=1.9.7.Final
KEYCLOAK_FILENAME=keycloak-$KEYCLOAK_VERSION
KEYCLOAK_ARCHIVE_NAME=$KEYCLOAK_FILENAME.tar.gz
KEYCLOAK_DOWNLOAD_ADDRESS=http://downloads.jboss.org/keycloak/$KEYCLOAK_VERSION/$KEYCLOAK_ARCHIVE_NAME

INSTALL_DIR=/opt
KEYCLOAK_FULL_DIR=$INSTALL_DIR/$KEYCLOAK_FILENAME
KEYCLOAK_DIR=$INSTALL_DIR/keycloak

KEYCLOAK_USER="keycloak"
KEYCLOAK_SERVICE="keycloak"

KEYCLOAK_STARTUP_TIMEOUT=240
KEYCLOAK_SHUTDOWN_TIMEOUT=30

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

echo "Downloading: $KEYCLOAK_DOWNLOAD_ADDRESS..."
[ -e "$KEYCLOAK_ARCHIVE_NAME" ] && echo 'Keycloak archive already exists.'
if [ ! -e "$KEYCLOAK_ARCHIVE_NAME" ]; then
  wget -q $KEYCLOAK_DOWNLOAD_ADDRESS
  if [ $? -ne 0 ]; then
    echo "Not possible to download Keycloak."
    exit 1
  fi
fi

echo "Cleaning up..."
rm -rf "$KEYCLOAK_DIR"
rm -rf "$KEYCLOAK_FULL_DIR"
rm -rf "/var/run/$KEYCLOAK_SERVICE/"
rm -f "/etc/init.d/$KEYCLOAK_SERVICE"

echo "Installation..."
mkdir $KEYCLOAK_FULL_DIR
tar -xzf $KEYCLOAK_ARCHIVE_NAME -C $INSTALL_DIR
ln -s $KEYCLOAK_FULL_DIR/ $KEYCLOAK_DIR
useradd -s /sbin/nologin $KEYCLOAK_USER
chown -R $KEYCLOAK_USER:$KEYCLOAK_USER $KEYCLOAK_DIR
chown -R $KEYCLOAK_USER:$KEYCLOAK_USER $KEYCLOAK_DIR/

echo "Registering keycloak as service..."
# if Debian-like distribution
#if [ -r /lib/lsb/init-functions ]; then
#    cp $KEYCLOAK_DIR/bin/init.d/wildfly-init-debian.sh /etc/init.d/$KEYCLOAK_SERVICE
#    sed -i -e 's,NAME=keycloak,NAME='$KEYCLOAK_SERVICE',g' /etc/init.d/$KEYCLOAK_SERVICE
#    KEYCLOAK_SERVICE_CONF=/etc/default/$KEYCLOAK_SERVICE
#fi

# if RHEL-like distribution
#if [ -r /etc/init.d/functions ]; then
#    cp $KEYCLOAK_DIR/bin/init.d/-init-redhat.sh /etc/init.d/$KEYCLOAK_SERVICE
#    KEYCLOAK_SERVICE_CONF=/etc/default/keycloak.conf
#fi

# if neither Debian nor RHEL like distribution
#if [ ! -r /lib/lsb/init-functions -a ! -r /etc/init.d/functions ]; then
cat > /etc/init.d/$KEYCLOAK_SERVICE << "EOF"
#!/bin/sh
### BEGIN INIT INFO
# Provides:          ${KEYCLOAK_SERVICE}
# Required-Start:    $local_fs $remote_fs $network $syslog
# Required-Stop:     $local_fs $remote_fs $network $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start/Stop ${KEYCLOAK_FILENAME}
### END INIT INFO
KEYCLOAK_USER=${KEYCLOAK_USER}
KEYCLOAK_DIR=${KEYCLOAK_DIR}
case "$1" in
start)
echo "Starting ${KEYCLOAK_FILENAME}..."
start-stop-daemon --start --background --chuid $KEYCLOAK_USER --exec $KEYCLOAK_DIR/bin/standalone.sh
exit $?
;;
stop)
echo "Stopping ${KEYCLOAK_FILENAME}..."
start-stop-daemon --start --quiet --background --chuid $KEYCLOAK_USER --exec $KEYCLOAK_DIR/bin/jboss-cli.sh -- --connect command=:shutdown
exit $?
;;
log)
echo "Showing server.log..."
tail -500f $KEYCLOAK_DIR/standalone/log/server.log
;;
*)
echo "Usage: /etc/init.d/keycloak {start|stop}"
exit 1
;;
esac
exit 0
EOF
sed -i -e 's,${KEYCLOAK_USER},'$KEYCLOAK_USER',g; s,${KEYCLOAK_FILENAME},'$KEYCLOAK_FILENAME',g; s,${KEYCLOAK_SERVICE},'$KEYCLOAK_SERVICE',g; s,${KEYCLOAK_DIR},'$KEYCLOAK_DIR',g' /etc/init.d/$KEYCLOAK_SERVICE
#fi

chmod 755 /etc/init.d/$KEYCLOAK_SERVICE

if [ ! -z "$KEYCLOAK_SERVICE_CONF" ]; then
    echo "Configuring service..."
    echo JBOSS_HOME=\"$KEYCLOAK_DIR\" > $KEYCLOAK_SERVICE_CONF
    echo JBOSS_USER=$KEYCLOAK_USER >> $KEYCLOAK_SERVICE_CONF
    echo STARTUP_WAIT=$KEYCLOAK_STARTUP_TIMEOUT >> $KEYCLOAK_SERVICE_CONF
    echo SHUTDOWN_WAIT=$KEYCLOAK_SHUTDOWN_TIMEOUT >> $KEYCLOAK_SERVICE_CONF
fi

echo "Configuring application server..."
sed -i -e 's,<deployment-scanner path="deployments" relative-to="jboss.server.base.dir" scan-interval="5000"/>,<deployment-scanner path="deployments" relative-to="jboss.server.base.dir" scan-interval="5000" deployment-timeout="'$KEYCLOAK_STARTUP_TIMEOUT'"/>,g' $KEYCLOAK_DIR/standalone/configuration/standalone.xml
sed -i -e 's,<inet-address value="${jboss.bind.address:127.0.0.1}"/>,<any-address/>,g' $KEYCLOAK_DIR/standalone/configuration/standalone.xml
#sed -i -e 's,<socket-binding name="ajp" port="${jboss.ajp.port:8009}"/>,<socket-binding name="ajp" port="${jboss.ajp.port:28009}"/>,g' $KEYCLOAK_DIR/standalone/configuration/standalone.xml
#sed -i -e 's,<socket-binding name="http" port="${jboss.http.port:8080}"/>,<socket-binding name="http" port="${jboss.http.port:28080}"/>,g' $KEYCLOAK_DIR/standalone/configuration/standalone.xml
#sed -i -e 's,<socket-binding name="https" port="${jboss.https.port:8443}"/>,<socket-binding name="https" port="${jboss.https.port:28443}"/>,g' $KEYCLOAK_DIR/standalone/configuration/standalone.xml
#sed -i -e 's,<socket-binding name="osgi-http" interface="management" port="8090"/>,<socket-binding name="osgi-http" interface="management" port="28090"/>,g' $KEYCLOAK_DIR/standalone/configuration/standalone.xml

service $KEYCLOAK_SERVICE start

echo "Done."
