#!/usr/bin/env bash

export INSTALL_SRC=/vagrant
printenv > env.properties

KEYCLOAK_VERSION=11.0.3
POSTGRES_VERSION=42.2.18
KEYCLOAK_URL=http://downloads.jboss.org/keycloak/${KEYCLOAK_VERSION}/keycloak-${KEYCLOAK_VERSION}.tar.gz
POSTGRESQL_URL=https://jdbc.postgresql.org/download/postgresql-${POSTGRES_VERSION}.jar

echo "===================================================================="
echo "                      INSTALLATION KEYCLOAK                         "
echo "===================================================================="

echo "--------------------------------------------------------------------"
echo " Etape 0: Mise a jour des packages                                  "
echo "--------------------------------------------------------------------"
#sudo yum check-update 
#sudo yum clean all -y
#sudo yum update -y


sudo yum install -y wget

echo "--------------------------------------------------------------------"
echo "Step 1: Installation JDK                                            "
echo "--------------------------------------------------------------------"
sudo yum install -y java-1.8.0-openjdk
#sudo yum install -y java-1.8.0-openjdk-devel -y


echo "--------------------------------------------------------------------"
echo "Step 2: Creation d'un user/group keycloak:keycloak                  "
echo "--------------------------------------------------------------------"
#sudo groupadd -r keycloak                   #pb
#sudo useradd  -r -g keycloak -d /opt/keycloak -s /sbin/nologin keycloak #pb


echo "--------------------------------------------------------------------"
echo "Step 3: Téléchargement de keycloak                                  "
echo "--------------------------------------------------------------------"
if [ -f "${INSTALL_SRC}/downloads/keycloak-${KEYCLOAK_VERSION}.tar.gz" ];
then
    echo "Installation Keycloak depuis ${INSTALL_SRC}/downloads/keycloak-${KEYCLOAK_VERSION} ..."
else
    echo "Téléchargement de  keycloak-${KEYCLOAK_VERSION} ..."
    echo "depuis "${KEYCLOAK_URL}" "
    mkdir -p ${INSTALL_SRC}/downloads
    wget -q -O ${INSTALL_SRC}/downloads/keycloak-${KEYCLOAK_VERSION}.tar.gz "${KEYCLOAK_URL}" 
    #curl -L -o ${INSTALL_SRC}/downloads/keycloak-${KEYCLOAK_VERSION}.tar.gz "${KEYCLOAK_URL}"

    if [ $? != 0 ];
    then
        echo "GRAVE: Téléchargement impossible depuis ${KEYCLOAK_URL}"	
        exit 1
    fi
    echo "Installation Keycloak ..."
fi



echo "--------------------------------------------------------------------"
echo "Step 4: Extraction keycloak-${KEYCLOAK_VERSION}.tar.gz dans /opt    "
echo "--------------------------------------------------------------------" 
sudo tar xfz ${INSTALL_SRC}/downloads/keycloak-${KEYCLOAK_VERSION}.tar.gz -C /opt



echo "--------------------------------------------------------------------"
echo "Step 5: Creation d'un lien symbolique /opt/keycloak pointant sur    "
echo "        le rep d'install /opt/keycloak-${KEYCLOAK_VERSION}          "
echo "--------------------------------------------------------------------"
sudo ln -sfn /opt/keycloak-${KEYCLOAK_VERSION} /opt/keycloak



echo "--------------------------------------------------------------------"
echo "Step 6: Permettre au user keycloak:keycloak d'execute keycloak [KO] "
echo "--------------------------------------------------------------------"
#sudo chown -R keycloak:keycloak /opt/keycloak   #pb



echo "--------------------------------------------------------------------"
echo "Step 7: Limiter l'acces au repertoire standalone [KO]               "
echo "--------------------------------------------------------------------" 
#sudo -u keycloak chmod 700 /opt/keycloak/standalone   #pb
#sudo chmod 777 /opt/keycloak/standalone


echo "====================================================================="
echo "                       CONFIGURATION KEYCLOAK                        "
echo "====================================================================="
configured_file="/opt/keycloak/configured"
if [ ! -e "$configured_file" ]; then
    touch "$configured_file"
    sudo ${INSTALL_SRC}/keycloak_configure.sh
fi

echo "===================================================================="
echo "                      BOOTSTRAP KEYCLOAK                            "
echo "===================================================================="
sudo ${INSTALL_SRC}/keycloak_startup.sh


