#!/usr/bin/env bash

INSTALL_SRC=/vagrant

echo "-------------------------------------------------------------------"
echo "Step 1: Configuration systemD : Copier de la config keycloak.conf  "
echo "        dans /etc/keycloak                                         "
echo "-------------------------------------------------------------------"
sudo mkdir -p /etc/keycloak
sudo cp ${INSTALL_SRC}/service/keycloak.conf /etc/keycloak/
sudo more /etc/keycloak/keycloak.conf


echo "-------------------------------------------------------------------"
echo "Step 2 : Configuration systemD : Copier et configurer le fichier de"
echo "         demarrage lauch.sh                                        "
echo "-------------------------------------------------------------------"
sudo cp ${INSTALL_SRC}/service/launch.sh /opt/keycloak/bin/
sudo more /opt/keycloak/bin/launch.sh
#sudo more | ls -la /opt/keycloak/bin/lauch.sh
sudo chmod +x /opt/keycloak/bin/launch.sh
#sudo chown keycloak: /opt/keycloak/bin/launch.sh



echo "-------------------------------------------------------------------"
echo "Step 3 : Configuration SystemD : Copier et configurer le fichier   "
echo "         de service keycloak.service                            "
echo "-------------------------------------------------------------------"
sudo cp ${INSTALL_SRC}/service/keycloak.service /etc/systemd/system/
more /etc/systemd/system/keycloak.service


echo "-------------------------------------------------------------------"
echo "Step 4: Démarrage du service keycloak                             "
echo "-------------------------------------------------------------------"
sudo systemctl daemon-reload
sudo systemctl start keycloak
sudo systemctl enable keycloak


echo "-------------------------------------------------------------------"
echo "Step 5: Etat du service keycloak                                  "
echo "-------------------------------------------------------------------"
sudo systemctl status keycloak

echo "-------------------------------------------------------------------"
echo "Step 15: logs du server keycloak                     "
echo "-------------------------------------------------------------------"
sudo tail -f /opt/keycloak/standalone/log/server.log
#journalctl -u keycloak.service


#voir https://medium.com/@hasnat.saeed/setup-keycloak-server-on-ubuntu-18-04-ed8c7c79a2d9
#sudo /sbin/service keycloak start
echo "-----------------------------------------------------"
echo "Step 16: Opening port 8080 on iptables ...           "
echo "-----------------------------------------------------"
#iptables -I INPUT 3 -p tcp -m state --state NEW -m tcp --dport 8080 -j ACCEPT
#iptables-save > /etc/sysconfig/iptables

