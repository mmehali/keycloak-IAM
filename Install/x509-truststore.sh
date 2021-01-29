#!/bin/bash
 
 INSTALL_SRC=/vagrant
 KEYSTORES_DIR=/opt/keycloak/standalone/configuration/keystores
 echo "-----------------------------------------------------------------"
 echo "   Configuration du truststore                                   "
 echo "-----------------------------------------------------------------"
  
 # Auto-generate the Keycloak truststore if X509_CA_BUNDLE was provided
 echo "- Configuration du truststore : "${KEYSTORES_DIR}/truststore.jks"
  
 echo "- Configuration d'un mot de passe pour le truststore"
 PASSWORD=$(openssl rand -base64 32 2>/dev/null)
 TEMPORARY_CERTIFICATE="temporary_ca.crt"
 if [ -n "${X509_CA_BUNDLE}" ]; then
   pushd /tmp >& /dev/null
   echo "- creation Keykloak truststore "
   # On utlise le cat, afin de spécifier plusieurs CA Bundles séparés par des espaces
   X509_CA_BUNDLE=/vagrant/ca_bundles/*.crt
   X509_CA_BUNDLE=/ca.crt /ca2.crt
   
   echo "- copier ${X509_CA_BUNDLE} dans temporary_ca.crt"
   cat ${X509_CA_BUNDLE} > temporary_ca.crt
    
   echo "- csplit -s -z -f crt- temporary_ca.crt "/-----BEGIN CERTIFICATE-----/" '{*}'"
   csplit -s -z -f crt- temporary_ca.crt "/-----BEGIN CERTIFICATE-----/" '{*}'
    
   for CERT_FILE in crt-*; do
     echo "- sudo keytool -import -noprompt -keystore "${KEYSTORES_DIR}/truststore.jks" -file "${CERT_FILE}" -storepass "${PASSWORD}" -alias "service-${CERT_FILE}""
     sudo keytool -import -noprompt -keystore "${KEYSTORES_DIR}/truststore.jks" -file "${CERT_FILE}" \
     -storepass "${PASSWORD}" -alias "service-${CERT_FILE}" >& /dev/null
   done

    if [ -f "${KEYSTORES_DIR}/truststore.jks" ]; then
      echo "- Etape 10.2.2 : le truststore keycloak crée avec succes : ${KEYSTORES_DIR}/truststore.jks"
    else
      echo "- Etape 10.2.2 : impossible de creer le truststore keycloak : ${KEYSTORES_DIR}/truststore.jks"
    fi

    # Import existing system CA certificates into the newly generated truststore
    SYSTEM_CACERTS=$(readlink -e $(dirname $(readlink -e $(which keytool)))"/../lib/security/cacerts")
    if sudo keytool -v -list -keystore "${SYSTEM_CACERTS}" -storepass "changeit" > /dev/null; then
      echo "- Importer les certificates de Java CA certificate bundle dans le truststore Keycloak"
      echo "- sudo keytool -importkeystore -noprompt -srckeystore "${SYSTEM_CACERTS}" -destkeystore "${KEYSTORES_DIR}/truststore.jks" -srcstoretype jks -deststoretype jks -storepass "${PASSWORD}" -srcstorepass "changeit""
      sudo keytool -importkeystore -noprompt \
      -srckeystore "${SYSTEM_CACERTS}" \
      -destkeystore "${KEYSTORES_DIR}/truststore.jks" \
      -srcstoretype jks -deststoretype jks \
      -storepass "${PASSWORD}" -srcstorepass "changeit" >& /dev/null
      if [ "$?" -eq "0" ]; then
        echo "Successfully imported certificates from system's Java CA certificate bundle into Keycloak truststore at: ${KEYSTORES_DIR}/truststore.jks"
      else
        echo "Failed to import certificates from system's Java CA certificate bundle into Keycloak truststore!"
      fi
    fi
    
    echo "- Etape 10.2.2 : ajouter les parametres suivant aux fichier /opt/keycloak/bin/.jbossclirc"
    echo "# set keycloak_tls_truststore_password=${PASSWORD}"
    echo "# set keycloak_tls_truststore_file=${KEYSTORES_DIR}/truststore.jks"
    echo "# set configuration_file=standalone-ha.xml"
    
    echo "set keycloak_tls_truststore_password=${PASSWORD}" >> "/opt/keycloak/bin/.jbossclirc"
    echo "set keycloak_tls_truststore_file=${KEYSTORES_DIR}/truststore.jks" >> "/opt/keycloak/bin/.jbossclirc"
    echo "set configuration_file=standalone-ha.xml" >> "/opt/keycloak/bin/.jbossclirc"
    
    echo "- Etape 10.2.2 : executer sudo /opt/keycloak/bin/jboss-cli.sh --file=${INSTALL_SRC}/cli/x509-truststore.cli >& /dev/null"
    sudo /opt/keycloak/bin/jboss-cli.sh --file=${INSTALL_SRC}/cli/x509-truststore.cli  --properties=env.properties >& /dev/null
    sed -i '$ d' "/opt/keycloak/bin/.jbossclirc"
    
    popd >& /dev/null
  fi
