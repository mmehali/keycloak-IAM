FROM jboss/keycloak:11.0.3

# Keycloak User
ENV KEYCLOAK_ADMIN_USER admin
ENV KEYCLOAK_ADMIN_PASSWORD admin

# Logging Properties
ENV LOG_SERVER_URL   udp:graylog
ENV LOG_SERVER_PORT  12123

# JDBC Connection Options
ENV JDBC_URL         JDBC_URL=jdbc:postgresql://sso-db/iam_keycloak
ENV JDBC_USER        keycloak
ENV JDBC_PASSWORD    keycloak
ENV JDBC_DRIVERNAME  postgres

# JVM Options
ENV JAVA_OPTS        -Xms128M \
                     -Xmx2G \
                     -XX:MetaspaceSize=128M \
                     -XX:MaxMetaspaceSize=256m \
                     -Djava.net.preferIPv4Stack=true \
                     -Djboss.modules.system.pkgs=org.jboss.byteman \
                     -Djava.awt.headless=true \
                     -Djava.net.preferIPv4Stack=true
USER root

RUN ln -f -s /usr/share/zoneinfo/Europe/Berlin /etc/localtime

USER jboss

ADD /modules /opt/jboss/keycloak/modules

COPY docker-entrypoint.sh /opt/jboss 
COPY keycloak-setup.cli /opt/jboss/keycloak

COPY docker-entrypoint.sh /opt/jboss/tools
COPY keycloak-setup.cli /opt/jboss/tools

CMD ["--server-config", "standalone-ha.xml"]
