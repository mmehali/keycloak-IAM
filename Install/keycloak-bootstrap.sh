#!/usr/bin/env bash

KEYCLOAK_VERSION=11.0.3
POSTGRES_VERSION=42.2.18
KEYCLOAK_URL=http://downloads.jboss.org/keycloak/${KEYCLOAK_VERSION}/keycloak-${KEYCLOAK_VERSION}.tar.gz
POSTGRESQL_URL=https://jdbc.postgresql.org/download/postgresql-${POSTGRES_VERSION}.jar

sudo tar xfz /vagrant/downloads/keycloak-${KEYCLOAK_VERSION}.tar.gz -C /opt
echo "----------------------------------------------------------"
echo " Etape 0: Mise a jour des packages                        "
echo "----------------------------------------------------------"
#sudo yum check-update 
#sudo yum clean all -y
#sudo yum update -y


sudo yum install -y wget

echo "-----------------------------------------------------------"
echo "Step 1: Installation JDK                                   "
echo "-----------------------------------------------------------"
sudo yum install -y java-1.8.0-openjdk
#sudo yum install -y java-1.8.0-openjdk-devel -y


echo "------------------------------------------------------------"
echo "Step 2: Creer  user/group keycloak:keycloak                 "
echo "------------------------------------------------------------"
#sudo groupadd -r keycloak               #pb
#sudo useradd  -r -g keycloak -d /opt/keycloak -s /sbin/nologin keycloak #pb


echo "-------------------------------------------------------------"
echo "Step 3: Telechargement de keycloak                           "
echo "-------------------------------------------------------------"
if [ -f "/vagrant/downloads/keycloak-${KEYCLOAK_VERSION}.tar.gz" ];
then
    echo "Installation Keycloak depuis /vagrant/downloads/keycloak-${KEYCLOAK_VERSION} ..."
else
    echo "Téléchargement de  keycloak-${KEYCLOAK_VERSION} ..."
    echo "depuis "${KEYCLOAK_URL}" "
    mkdir -p /vagrant/downloads
    wget -q -O /vagrant/downloads/keycloak-${KEYCLOAK_VERSION}.tar.gz "${KEYCLOAK_URL}" 
    #curl -L -o /vagrant/downloads/keycloak-${KEYCLOAK_VERSION}.tar.gz "${KEYCLOAK_URL}"

    if [ $? != 0 ];
    then
        echo "GRAVE: Téléchargement keycloak impossible depuis ${KEYCLOAK_URL}"	
        exit 1
    fi
    echo "Installation Keycloak ..."
fi



echo "------------------------------------------------------------------"
echo "Step 4: Extraction keycloak-${KEYCLOAK_VERSION}.tar.gz dans /opt  "
echo "------------------------------------------------------------------" 
sudo tar xfz /vagrant/downloads/keycloak-${KEYCLOAK_VERSION}.tar.gz -C /opt


echo "--------------------------------------------------------------------"
echo "Step 5: Creer un lien symbolique pointant sur le rep d'install      "
echo "--------------------------------------------------------------------"
sudo ln -sfn /opt/keycloak-${KEYCLOAK_VERSION} /opt/keycloak


echo "--------------------------------------------------------"
echo "Step 6: Donner l'acces (exec) au user/groug keycloak    "
echo "--------------------------------------------------------"
#sudo chown -R keycloak:keycloak /opt/keycloak   #pb



echo "--------------------------------------------------------"
echo "Step 7: Limiter l'acces au repertoire standalone        "
echo "--------------------------------------------------------" 
#sudo -u keycloak chmod 700 /opt/keycloak/standalone   #pb
#sudo chmod 777 /opt/keycloak/standalone


echo "---------------------------------------------------------"
echo "Step 8: Telecharger le driver postgresql                 " 
echo "---------------------------------------------------------"
if [ -f "/vagrant/downloads/postgresql-${POSTGRES_VERSION}.jar" ];
then
    echo "Installation postgresql depuis /vagrant/downloads/postgresql-${POSTGRES_VERSION}.jar..."
else
    echo "Téléchargement de  postgresql-${POSTGRES_VERSION}.jar ..."
    echo "depuis "-${POSTGRESQL_URL}" "
    wget -q -O /vagrant/downloads/postgresql-${POSTGRES_VERSION}.jar  "${POSTGRES_URL}"
    #if [ $? != 0 ];
    #then
       # echo "GRAVE: Téléchargement du driver Postgres impossible depuis ${POSTGRESQL_URL}"	
       # exit 1
    #fi
    echo "Installation du driver postgres ..."
fi

echo "----------------------------------------------------------"
echo "Step 9: installation du Module postgres                   "
echo "----------------------------------------------------------" 
#sudo mkdir -p /opt/keycloak/modules/system/layers/base/org/postgresql/jdbc/main
#sudo cp /vagrant/downloads/postgresql-${POSTGRES_VERSION}.jar /opt/keycloak/modules/system/layers/base/org/postgresql/jdbc/main/
#sudo cp /vagrant/cli/postgres/module.xml /opt/keycloak/modules/system/layers/base/org/postgresql/jdbc/main/


echo "-----------------------------------------------------------"
echo "Step 10 : configuration keycloak                           "
echo "-----------------------------------------------------------"
sudo /opt/keycloak/bin/jboss-cli.sh --file=/vagrant/cli/standalone-ha-config.cli

configured_file="/opt/keycloak/configured"
#if [ ! -e "$configured_file" ]; then
    #touch "$configured_file"
    echo "Step 10.1 : configuration de postgres                    "
    #sudo /opt/keycloak/bin/jboss-cli.sh --file=/vagrant/cli/postgres/standalone-ha-config.cli
    echo "Step 10.2 : configuration de x509 (keyStore, truststore) "
    sudo /vagrant/x509.sh
    echo "Step 10.3 : configuration des jgroups                    "
    sudo /vagrant/jgroups.sh
    echo "Step 10.4 : configuration du cache (infinspan)           "
    sudo /vagrant/infinispan.sh
    echo "Step 10.5 : configuration des statistiques               "
    sudo /vagrant/statistics.sh
    echo "Step 10.6 : configuration vault                          "
    sudo /vagrant/vault.sh
    echo "Step 10.7 : lancement de scripts spécifiques             "
    sudo /vagrant/autorun.sh
#fi

sudo rm -rf /opt/keycloak/standalone/configuration/standalone_xml_history


echo "-----------------------------------------------------"
echo "Step 11: ajouter un administateur keycloak           "
echo "-----------------------------------------------------"
sudo /opt/keycloak/bin/add-user-keycloak.sh -u admin -p admin



