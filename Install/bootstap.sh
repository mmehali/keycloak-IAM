#!/usr/bin/env bash

# This script downloads and installs Keycloak.
# Use the VERSION environment variable below to define the version to be used.

VERSION=11.0.3

DOWNLOAD_URL=http://downloads.jboss.org/keycloak/${VERSION}/keycloak-${VERSION}.tar.gz
POSTGRESQL_URL=https://jdbc.postgresql.org/download/postgresql-42.2.18.jar


sudo yum check-update 
sudo yum clean all
sudo yum update 


sudo yum install -y wget

echo "--------------------------------------------"
echo "Step 1: Installation JDK                    "
echo "--------------------------------------------"
sudo yum install -y java-1.8.0-openjdk
#sudo yum install -y java-1.8.0-openjdk-devel -y


echo "--------------------------------------------------"
echo "Step 5: Creer  user/group keycloak pour keycloak "
echo "--------------------------------------------------"
sudo groupadd -r keycloak
sudo useradd  -r -g keycloak -d /opt/keycloak -s /sbin/nologin keycloak


echo "--------------------------------------------"
echo "Step 2 : Telecharger keycloak               "
echo "--------------------------------------------"
if [ -f "/vagrant/downloads/keycloak-${VERSION}.tar.gz" ];
then
    echo "Installation Keycloak depuis /vagrant/downloads/keycloak-${VERSION} ..."
else
    echo "Téléchargement de  keycloak-${VERSION} ..."
    mkdir -p /vagrant/downloads
    wget -q -O /vagrant/downloads/keycloak-${VERSION}.tar.gz "${DOWNLOAD_URL}"
    if [ $? != 0 ];
    then
        echo "FATAL: Failed to download Keycloak from ${DOWNLOAD_URL}"	
        exit 1
    fi

    echo "Installing Keycloak ..."
fi

echo "------------------------------------------------"
echo "Step 3 : Extractraire keycloak tar.gz dans /opt "
echo "------------------------------------------------" 
sudo tar xfz /vagrant/downloads/keycloak-${VERSION}.tar.gz -C /opt

echo "--------------------------------------------------------------------"
echo "Step 4: create a lien symbolique pointant sur le rep d'installation "
echo "--------------------------------------------------------------------"
sudo ln -s /opt/keycloak-${VERSION} /opt/keycloak


echo "-----------------------------------------------------"
echo "Step 6: donner l'acces (exec) au user/groug keycloak "
echo "-----------------------------------------------------"
sudo chown -RH keycloak: /opt/keycloak



echo "--------------------------------------------------"
echo "Step 7 : Limiter l'acces au repertoire standalone "
echo "--------------------------------------------------" 
#sudo -u keycloak chmod 700 /opt/keycloak/standalone
#sudo chmod 777 /opt/keycloak/standalone

echo "-----------------------------------------------------"
echo "Step 8 : Telecharger le driver postgresql            " 
echo "-----------------------------------------------------"
wget -q -O /vagrant/downloads/postgresql-42.2.18.jar  "${POSTGRESQL_URL}"

echo "-----------------------------------------------------"
echo "Step 9 : configuration keycloak avant demarrage      "
echo "-----------------------------------------------------"
sudo -u keycloak /opt/keycloak/bin/jboss-cli.sh 'embed-server,/subsystem=datasources/jdbc-driver=mysql:add(
         driver-name=postgresql,
	     driver-module-name=org.mysql,
	     driver-class-name=org.postgresql.xa.PGXADataSource
	     )'


sudo /opt/keycloak/bin/jboss-cli.sh --file=/vagrant/keycloak_configure.cli


echo "-----------------------------------------------------"
echo "Step 10: Configure keycloak to be run as a service   "
echo "-----------------------------------------------------"
sudo mkdir -p /etc/keycloak

sudo cp /vagrant/launch.sh /opt/keycloak-${VERSION}/bin/
sudo sh -c 'chmod +x /opt/keycloak-${VERSION}/bin'
#sudo chown keycloak: /opt/keycloak-${VERSION}/bin/launch.sh

sudo cp /vagrant/keycloak.service /etc/systemd/system/

#sudo cp /vagrant/keycloak.conf /etc/keycloak-${VERSION}/

echo "-----------------------------------------------------"
echo "Step 11: start the  keycloak service"
echo "-----------------------------------------------------"
sudo systemctl daemon-reload
sudo systemctl start keycloak
sudo systemctl enable keycloak



#sudo /sbin/service keycloak start
echo "-----------------------------------------------------"
echo "Step 11: Opening port 8080 on iptables ...           "
echo "-----------------------------------------------------"
iptables -I INPUT 3 -p tcp -m state --state NEW -m tcp --dport 8080 -j ACCEPT
iptables-save > /etc/sysconfig/iptables

