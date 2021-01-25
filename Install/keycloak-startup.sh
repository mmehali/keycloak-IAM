echo "-----------------------------------------------------"
echo "Step 12: Configuration systemD                       "
echo "-----------------------------------------------------"

echo "Step 12.1 : Copier de la config keycloak.conf dans /etc/keycloak"
sudo mkdir -p /etc/keycloak
sudo cp /vagrant/service/keycloak.conf /etc/keycloak/
sudo more /etc/keycloak/keycloak.conf

echo "Step 12.2 : Copier et configurer le fichier de demarrage lauch.sh"
sudo cp /vagrant/service/launch.sh /opt/keycloak/bin/
sudo more /opt/keycloak/bin/launch.sh
#sudo more | ls -la /opt/keycloak/bin/lauch.sh
sudo chmod +x /opt/keycloak/bin/launch.sh
#sudo chown keycloak: /opt/keycloak/bin/launch.sh

echo "Step 12.3 : Copier et configurer le fichier de service keycloak.service"
sudo cp /vagrant/service/keycloak.service /etc/systemd/system/
more /etc/systemd/system/keycloak.service


echo "-----------------------------------------------------"
echo "Step 13: demarrage du service keycloak               "
echo "-----------------------------------------------------"
sudo systemctl daemon-reload
sudo systemctl start keycloak
sudo systemctl enable keycloak

echo "-----------------------------------------------------"
echo "Step 14: etat du service keycloak                    "
echo "-----------------------------------------------------"
sudo systemctl status keycloak

echo "-----------------------------------------------------"
echo "Step 15: logs du server keycloak                     "
echo "-----------------------------------------------------"
sudo tail -f /opt/keycloak/standalone/log/server.log
#journalctl -u keycloak.service

#voir https://medium.com/@hasnat.saeed/setup-keycloak-server-on-ubuntu-18-04-ed8c7c79a2d9

#sudo /sbin/service keycloak start
echo "-----------------------------------------------------"
echo "Step 16: Opening port 8080 on iptables ...           "
echo "-----------------------------------------------------"
#iptables -I INPUT 3 -p tcp -m state --state NEW -m tcp --dport 8080 -j ACCEPT
#iptables-save > /etc/sysconfig/iptables



