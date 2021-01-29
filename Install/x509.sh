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


  echo "-----------------------------------------------------------------"
  echo "   Configuration du truststore                                   "
  echo "-----------------------------------------------------------------"
  
  # Auto-generate the Keycloak truststore if X509_CA_BUNDLE was provided
  X509_CRT_DELIMITER="/-----BEGIN CERTIFICATE-----/"
  
  JKS_TRUSTSTORE_PATH="${KEYSTORES_DIR}/truststore.jks"
  echo "- Configuration du truststore : "${KEYSTORES_DIR}/truststore.jks"
  
  echo "- Configuration d'un mot de passe pour le truststore"
  PASSWORD=$(openssl rand -base64 32 2>/dev/null)
  TEMPORARY_CERTIFICATE="temporary_ca.crt"
  if [ -n "${X509_CA_BUNDLE}" ]; then
    pushd /tmp >& /dev/null
    echo "- Etape 10.2.2 : Creating Keycloak truststore.."
    # We use cat here, so that users could specify multiple CA Bundles using space or even wildcard:
    X509_CA_BUNDLE=/var/run/secrets/kubernetes.io/serviceaccount/*.crt
    # Note, that there is no quotes here, that's intentional. Once can use spaces in the $X509_CA_BUNDLE like this:
    X509_CA_BUNDLE=/ca.crt /ca2.crt
    
    echo "- Etape 10.2.2 : copier ${X509_CA_BUNDLE} dans ${TEMPORARY_CERTIFICATE}"
    cat ${X509_CA_BUNDLE} > ${TEMPORARY_CERTIFICATE}
    
    echo "- Etape 10.2.2 : csplit -s -z -f crt- "${TEMPORARY_CERTIFICATE}" "${X509_CRT_DELIMITER}" '{*}'"
    csplit -s -z -f crt- "${TEMPORARY_CERTIFICATE}" "${X509_CRT_DELIMITER}" '{*}'
    
    for CERT_FILE in crt-*; do
      echo "- Etape 10.2.2 : sudo keytool -import -noprompt -keystore "${JKS_TRUSTSTORE_PATH}" -file "${CERT_FILE}" -storepass "${PASSWORD}" -alias "service-${CERT_FILE}""
      sudo keytool -import -noprompt -keystore "${JKS_TRUSTSTORE_PATH}" -file "${CERT_FILE}" \
      -storepass "${PASSWORD}" -alias "service-${CERT_FILE}" >& /dev/null
    done

    if [ -f "${JKS_TRUSTSTORE_PATH}" ]; then
      echo "- Etape 10.2.2 : le truststore keycloak crée avec succes : ${JKS_TRUSTSTORE_PATH}"
    else
      echo "- Etape 10.2.2 : impossible de creer le truststore keycloak : ${JKS_TRUSTSTORE_PATH}"
    fi

    # Import existing system CA certificates into the newly generated truststore
    SYSTEM_CACERTS=$(readlink -e $(dirname $(readlink -e $(which keytool)))"/../lib/security/cacerts")
    if sudo keytool -v -list -keystore "${SYSTEM_CACERTS}" -storepass "changeit" > /dev/null; then
      echo "- Etape 10.2.2 : Importing certificates from system's Java CA certificate bundle into Keycloak truststore.."
      echo "- Etape 10.2.2 : sudo keytool -importkeystore -noprompt -srckeystore "${SYSTEM_CACERTS}" -destkeystore "${JKS_TRUSTSTORE_PATH}" -srcstoretype jks -deststoretype jks -storepass "${PASSWORD}" -srcstorepass "changeit""
      sudo keytool -importkeystore -noprompt \
      -srckeystore "${SYSTEM_CACERTS}" \
      -destkeystore "${JKS_TRUSTSTORE_PATH}" \
      -srcstoretype jks -deststoretype jks \
      -storepass "${PASSWORD}" -srcstorepass "changeit" >& /dev/null
      if [ "$?" -eq "0" ]; then
        echo "Successfully imported certificates from system's Java CA certificate bundle into Keycloak truststore at: ${JKS_TRUSTSTORE_PATH}"
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
