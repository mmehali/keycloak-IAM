#!/bin/bash
 
  #####################################################
  # creation de la cle privé et du certificat         #
  #####################################################
  #mkdir - p /etc/x509/https/
  #chmod 0700 /etc/x509/https/
  
  # creation de la cle privé
  #openssl genrsa 2048 > /etc/x509/https/tls.key
  #chmod 400 /etc/x509/https/tls.key
  
  # creation du certificat a partir de la clé privée.
  #openssl req -new -x509 -nodes -sha256 -days 365 -key tls.key -out tls.crt
  
  ######################################################
  # Copier la cle privée et le certificat              #
  ######################################################
  echo "- Etape 10.2.1 : Copier la cle privée et le certificat: creation repertoire /etc/x509/https"
  if [ ! -d "/etc/x509/https" ]; then
    mkdir -p /etc/x509/https
  fi
  
  echo "- Etape 10.2.1 : Copier la cle privée et le certificat: copier tls.key et tls.crt dans /etc/x509/https"
  cp /vagrant/certificats/tls.key /etc/x509/https/
  cp /vagrant/certificats/tls.crt /etc/x509/https/
   
   
  KEYSTORES_STORAGE=/opt/keycloak/standalone/configuration/keystores

  echo "- Etape 10.2.1 : Creating https keystore : creer repertoire ${KEYSTORES_STORAGE} "
  if [ ! -d "${KEYSTORES_STORAGE}" ]; then
    mkdir -p "${KEYSTORES_STORAGE}"
  fi


  # Auto-generate the https keystore if volumes for OpenShift's
  # serving x509 certificate secrets service were properly mounted
  echo "Auto-generate the https keystore "
  
  echo "- Etape 10.2.1 : Creating https keystore : genérer un mot de passe de 32 caracteres et l'encode en base64"
  PASSWORD=$(openssl rand -base64 32)
    
  if [ -f "/etc/x509/https/tls.key" ] && [ -f "/etc/x509/https/tls.crt" ]; then
     echo "Creating https keystore via OpenShift's service serving x509 certificate secrets.."
     
     echo "- Etape 10.2.1 : creation de keysrore ${KEYSTORES_STORAGE}/https-keystore.pk12"
     openssl pkcs12 -export -name  keycloak-https-key -inkey /etc/x509/https/tls.key \
      -in    /etc/x509/https/tls.crt -out ${KEYSTORES_STORAGE}/https-keystore.pk12 \
      -password pass:"${PASSWORD}" >& /dev/null
     
     echo "- Etape 10.2.1 : import keystore in ${KEYSTORES_STORAGE}/https-keystore.jks"
     echo "keytool -importkeystore -noprompt -srcalias keycloak-https-key -destalias keycloak-https-key -srckeystore  ${KEYSTORES_STORAGE}/https-keystore.pk12 -srcstoretype pkcs12 -destkeystore ${KEYSTORES_STORAGE}/https-keystore.jks -storepass "${PASSWORD}" -srcstorepass "${PASSWORD}" "
       
       
     sudo keytool -importkeystore -noprompt -srcalias keycloak-https-key \
      -destalias    keycloak-https-key \
      -srckeystore  ${KEYSTORES_STORAGE}/https-keystore.pk12 \
      -srcstoretype pkcs12 \
      -destkeystore ${KEYSTORES_STORAGE}/https-keystore.jks \
      -storepass    "${PASSWORD}" \ 
      -srcstorepass "${PASSWORD}" >& /dev/null

     
     if [ -f "${KEYSTORES_STORAGE}/https-keystore.jks" ]; then
        echo "keystore https crée avec succes : ${KEYSTORES_STORAGE}/https-keystore.jks"
     else
        echo "Impossible de creer le keystore https, verifier les permissions: ${KEYSTORES_STORAGE}/https-keystore.jks"
     fi

     echo "- Etape 10.2.1 : ajouter les parametres du keystore ci-dessous dans /opt/keycloak/bin/.jbossclirc"
     echo "# set keycloak_tls_keystore_password=${PASSWORD}" 
     echo "# set keycloak_tls_keystore_file=${KEYSTORES_STORAGE}/https-keystore.jks" 
     echo "# set configuration_file=standalone.xml"
     
     echo "set keycloak_tls_keystore_password=${PASSWORD}" >> /opt/keycloak/bin/.jbossclirc
     echo "set keycloak_tls_keystore_file=${KEYSTORES_STORAGE}/https-keystore.jks" >> /opt/keycloak/bin/.jbossclirc
     #echo "set configuration_file=standalone-ha.xml" >> "/opt/keycloak/bin/.jbossclirc"
     
     echo "- Etape 10.2.1 :- configurer le keystore en executant : /vagrant/cli/x509-keystore.cli"
     sudo /opt/keycloak/bin/jboss-cli.sh --file=/vagrant/cli/x509-keystore.cli >& /dev/null
     sed -i '$ d' "/opt/keycloak/bin/.jbossclirc"
  fi


  echo "- Etape 10.2.2 : Configuration du truststore "
  # Auto-generate the Keycloak truststore if X509_CA_BUNDLE was provided
  X509_CRT_DELIMITER="/-----BEGIN CERTIFICATE-----/"
  
  JKS_TRUSTSTORE_PATH="${KEYSTORES_STORAGE}/truststore.jks"
  echo "- Etape 10.2.2 : Configuration du truststore : "${KEYSTORES_STORAGE}/truststore.jks"
  
  echo "- Etape 10.2.2 : Configuration d'un mot de pas pour le truststore"
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
    echo "# set keycloak_tls_truststore_file=${KEYSTORES_STORAGE}/truststore.jks"
    echo "# set configuration_file=standalone-ha.xml"
    
    echo "set keycloak_tls_truststore_password=${PASSWORD}" >> "/opt/keycloak/bin/.jbossclirc"
    echo "set keycloak_tls_truststore_file=${KEYSTORES_STORAGE}/truststore.jks" >> "/opt/keycloak/bin/.jbossclirc"
    echo "set configuration_file=standalone-ha.xml" >> "/opt/keycloak/bin/.jbossclirc"
    
    echo "- Etape 10.2.2 : executer sudo /opt/keycloak/bin/jboss-cli.sh --file=/vagrant/cli/x509-truststore.cli >& /dev/null"
    sudo /opt/keycloak/bin/jboss-cli.sh --file=/vagrant/cli/x509-truststore.cli >& /dev/null
    sed -i '$ d' "/opt/keycloak/bin/.jbossclirc"
    
    popd >& /dev/null
  fi
