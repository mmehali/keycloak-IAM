#!/bin/bash
 
 INSTALL_SRC=/vagrant
 KEYSTORES_DIR=/opt/keycloak/standalone/configuration/keystores

  echo "--------------------------------------------------------"
  echo " Copier la cle privée  tls.key et le certificat tls.crt "
  echo " dans /etc/x509/https                                   "
  echo "--------------------------------------------------------"
  if [ ! -d "/etc/x509/https" ]; then
    mkdir -p /etc/x509/https
  fi
  
  cp ${INSTALL_SRC}/certificats/tls.key /etc/x509/https/
  cp ${INSTALL_SRC}/certificats/tls.crt /etc/x509/https/
   
   
 

 echo "---------------------------------------------------------------"
 echo " Creation du keystore ${KEYSTORES_DIR}/https-keystore.pk12 "
 echo "---------------------------------------------------------------"
 

 if [ ! -d "${KEYSTORES_DIR}" ]; then
    mkdir -p "${KEYSTORES_DIR}"
 fi

 # Auto-genérer un keystore https servant des certificats x509
 if [ -f "/etc/x509/https/tls.key" ] && [ -f "/etc/x509/https/tls.crt" ]; then
          
     echo "- Genérer et encoder un mot de passe de 32 caracteres"
     PASSWORD=$(openssl rand -base64 32 2>/dev/null)
  
     echo "- Creation du keysrore ${KEYSTORES_DIT}/https-keystore.pk12"
     echo "sudo openssl pkcs12 -export -name keycloak-https-key -inkey /etc/x509/https/tls.key -in /etc/x509/https/tls.crt -out ${KEYSTORES_DIR}/https-keystore.pk12 -password pass:"${PASSWORD}" >& /dev/null"
     sudo openssl pkcs12 -export -name keycloak-https-key -inkey /etc/x509/https/tls.key -in /etc/x509/https/tls.crt -out ${KEYSTORES_DIR}/https-keystore.pk12 -password pass:"${PASSWORD}" >& /dev/null
     
     echo "- Importer le keystore java dans ${KEYSTORES_DIR}/https-keystore.jks"
     echo "keytool -importkeystore -noprompt -srcalias keycloak-https-key -destalias keycloak-https-key -srckeystore ${KEYSTORES_DIR}/https-keystore.pk12 -srcstoretype pkcs12 -destkeystore ${KEYSTORES_DIR}/https-keystore.jks -storepass "${PASSWORD}" -srcstorepass "${PASSWORD}" "
     sudo keytool -importkeystore -noprompt  -srcalias keycloak-https-key -destalias keycloak-https-key -srckeystore ${KEYSTORES_DIR}/https-keystore.pk12 -srcstoretype pkcs12 -destkeystore ${KEYSTORES_DIR}/https-keystore.jks"-storepass "${PASSWORD}" -srcstorepass "${PASSWORD}" >& /dev/null
     
     if [ -f "${KEYSTORES_DIR}/https-keystore.jks" ]; then
        echo "keystore https crée avec succes : ${KEYSTORES_DIR}/https-keystore.jks"
     else
        echo "Impossible de creer le keystore https, verifier les permissions: ${KEYSTORES_DIR}/https-keystore.jks"
     fi

     echo "- Ajouter les parametres du keystore ci-dessous dans /opt/keycloak/bin/.jbossclirc"
     echo "set keycloak_tls_keystore_password=${PASSWORD}" >> "/opt/keycloak/bin/.jbossclirc"
     echo "set keycloak_tls_keystore_file=${KEYSTORES_DIR}/https-keystore.jks" >> "/opt/keycloak/bin/.jbossclirc"
     echo "set configuration_file=standalone.xml" >> "/opt/keycloak/bin/.jbossclirc"
     sudo /opt/keycloak/bin/jboss-cli.sh --file=${INSTALL_SRC}/cli/x509-keystore.cli >& /dev/null
     sed -i '$ d' "/opt/keycloak/bin/.jbossclirc"
     echo "set configuration_file=standalone-ha.xml" >> "/opt/keycloak/bin/.jbossclirc"
     /opt/keycloak/bin/jboss-cli.sh --file=${INSTALL_SRC}/cli/x509-keystore.cli >& /dev/null
     sed -i '$ d' "/opt/keycloak/bin/.jbossclirc"  
  fi

