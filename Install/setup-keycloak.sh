#!/usr/bin/env bash

KEYCLOAK_VERSION=11.0.3
POSTGRES_VERSION=42.2.18
KEYCLOAK_URL=http://downloads.jboss.org/keycloak/${KEYCLOAK_VERSION}/keycloak-${KEYCLOAK_VERSION}.tar.gz
POSTGRESQL_URL=https://jdbc.postgresql.org/download/postgresql-$POSTGRES_VERSION.jar

echo "---------------------------------------------"
echo " Etape 0 : Mise a jour des package           "
echo "---------------------------------------------"
sudo yum check-update 
sudo yum clean all -y
sudo yum update -y


sudo yum install -y wget

echo "--------------------------------------------"
echo "Step 1: Installation JDK                    "
echo "--------------------------------------------"
sudo yum install -y java-1.8.0-openjdk
#sudo yum install -y java-1.8.0-openjdk-devel -y


echo "--------------------------------------------------"
echo "Step 5: Creer  user/group keycloak pour keycloak "
echo "--------------------------------------------------"
#sudo groupadd -r keycloak
#sudo useradd  -r -g keycloak -d /opt/keycloak -s /sbin/nologin keycloak


echo "--------------------------------------------"
echo "Step 2 : Telechargement de keycloak         "
echo "--------------------------------------------"
if [ -f "/vagrant/downloads/keycloak-${KEYCLOAK_VERSION}.tar.gz" ];
then
    echo "Installation Keycloak depuis /vagrant/downloads/keycloak-${KEYCLOAK_VERSION} ..."
else
    echo "Téléchargement de  keycloak-${KEYCLOAK_VERSION} ..."
    mkdir -p /vagrant/downloads
    wget -q -O /vagrant/downloads/keycloak-${KEYCLOAK_VERSION}.tar.gz "${KEYCLOAK_URL}"
    if [ $? != 0 ];
    then
        echo "GRAVE: Téléchargement keycloak impossible depuis ${KEYCLOAK_URL}"	
        exit 1
    fi
    echo "Installation Keycloak ..."
fi



echo "------------------------------------------------------------------"
echo "Step 3 : Extraction keycloak-${KEYCLOAK_VERSION}.tar.gz dans /opt "
echo "------------------------------------------------------------------" 
sudo tar xvfz /vagrant/downloads/keycloak-${KEYCLOAK_VERSION}.tar.gz -C /opt



echo "--------------------------------------------------------------------"
echo "Step 4 : create a lien symbolique pointant sur le rep d'installation "
echo "--------------------------------------------------------------------"
test -d /opt/keycloak-${KEYCLOAK_VERSION} || sudo ln -s /opt/keycloak-${KEYCLOAK_VERSION} /opt/keycloak


echo "-----------------------------------------------------"
echo "Step 5 : donner l'acces (exec) au user/groug keycloak "
echo "-----------------------------------------------------"
#sudo chown -R keycloak:keycloak /opt/keycloak



echo "--------------------------------------------------"
echo "Step 7 : Limiter l'acces au repertoire standalone "
echo "--------------------------------------------------" 
#sudo -u keycloak chmod 700 /opt/keycloak/standalone
#sudo chmod 777 /opt/keycloak/standalone



echo "-----------------------------------------------------"
echo "Step 8 : Telecharger le driver postgresql            " 
echo "-----------------------------------------------------"
if [ -f "/vagrant/downloads/postgresql-${POSTGRES_VERSION}.jar" ];
then
    echo "Installation postgresql depuis /vagrant/downloads/postgresql-${POSTGRES_VERSION}.jar..."
else
    echo "Téléchargement de  postgresql-${POSTGRES_VERSION}.jar ..."
    wget -q -O /vagrant/downloads/postgresql-${POSTGRES_VERSION}.jar  "${POSTGRES_URL}"
    if [ $? != 0 ];
    then
        echo "GRAVE: Téléchargement du driver Postgres impossible depuis ${POSTGRES_URL}"	
        #exit 1
    fi
    echo "Installation du driver postgres ..."
fi

echo "------------------------------------------------"
echo "Step 9 : installation du driver postgres        "
echo "------------------------------------------------" 
sudo mkdir -p /opt/keycloak/modules/system/layers/base/org/postgresql/jdbc/main
sudo cd /opt/keycloak/modules/system/layers/base/org/postgresql/jdbc/main/
sudo cp /vagrant/downloads/postgresql-${POSTGRES_VERSION}.jar /opt/keycloak/modules/system/layers/base/org/postgresql/jdbc/main/
sudo cp /vagrant/postgres/module.xml /opt/keycloak/modules/system/layers/base/org/postgresql/jdbc/main/



echo "-----------------------------------------------------"
echo "Step 10 : configuration keycloak                     "
echo "-----------------------------------------------------"
sudo /opt/keycloak/bin/jboss-cli.sh --file=/vagrant/standalone-ha-config.cli
sudo rm -rf /opt/keycloak/standalone/configuration/standalone_xml_history


echo "-----------------------------------------------------"
echo "Step 11: ajouter un administateur keycloak           "
echo "-----------------------------------------------------"
sudo /opt/keycloak/bin/add-user-keycloak.sh -u admin -p admin


echo "-----------------------------------------------------"
echo "Step 12: Configuration systemD                       "
echo "-----------------------------------------------------"

echo "Step 12.1 : Copier de config keycloak.conf dans /etc/keycloak"
sudo mkdir -p /etc/keycloak
sudo cp /vagrant/service/keycloak.conf /etc/keycloak/
sudo more /etc/keycloak/keycloak.conf

echo "Step 12.2 : Copier et configurer le fichier de demarrage lauch.sh"
sudo cp /vagrant/service/launch.sh /opt/keycloak/bin/
sudo more /opt/keycloak/bin/lauch.sh
sudo more | ll /opt/keycloak/bin/lauch.sh
sudo chmod +x /opt/keycloak/bin/launch.sh
#sudo chown keycloak: /opt/keycloak/bin/launch.sh

echo "Step 12.3 : Copier et configurer le fichier de service keycloak.service"
sudo cp /vagrant/service/keycloak.service /etc/systemd/system/
more /etc/systemd/system/keycloak.service


echo "-----------------------------------------------------"
echo "Step 13: demarrage du service keycloak               "
echo "-----------------------------------------------------"
#sudo systemctl daemon-reload
sudo systemctl start keycloak
sudo systemctl enable keycloak

echo "-----------------------------------------------------"
echo "Step 14: etat du service keycloak                    "
echo "-----------------------------------------------------"
sudo systemctl status keycloak

echo "-----------------------------------------------------"
echo "Step 14: logs du server keycloak                     "
echo "-----------------------------------------------------"

#sudo tail -f /opt/keycloak/standalone/log/server.log
#journalctl -u keycloak.service

#voir https://medium.com/@hasnat.saeed/setup-keycloak-server-on-ubuntu-18-04-ed8c7c79a2d9

#sudo /sbin/service keycloak start
echo "-----------------------------------------------------"
echo "Step 13: Opening port 8080 on iptables ...           "
echo "-----------------------------------------------------"
iptables -I INPUT 3 -p tcp -m state --state NEW -m tcp --dport 8080 -j ACCEPT
iptables-save > /etc/sysconfig/iptables

