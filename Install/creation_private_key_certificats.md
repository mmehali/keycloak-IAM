 
##creation de la cle privé et du certificat  pour X509

### creer le repertoire 
```
mkdir - p /etc/x509/https/
chmod 0700 /etc/x509/https/
```
  
### creation de la cle privé
```
openssl genrsa 2048 > /etc/x509/https/tls.key
chmod 400 /etc/x509/https/tls.key
```
### creation du certificat a partir de la clé privée.
```
openssl req -new -x509 -nodes -sha256 -days 365 -key tls.key -out tls.crt
```