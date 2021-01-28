#!/usr/bin/env bash

#############
# identity providers
# swissid
IDENTITY_PROVIDER_ALIAS='provider1'
createIdentityProvider $REALM_NAME $IDENTITY_PROVIDER_ALIAS "provider1" oidc
$KCADM update identity-provider/instances/$IDENTITY_PROVIDER_ALIAS -r $REALM_NAME -s trustEmail=true -s 'config={"clientId": "'$CLIENT_ID_ISSUED_BY_SWISSID'", "clientSecret" : "'CLIENT_SECRET_ISSUED_BY_SWISSID'", "tokenUrl": "https://login.int.swissid.ch:443/idp/oauth2/access_token", "validateSignature": "true", "useJwksUrl": "true", "jwksUrl": "https://login.int.swissid.ch:443/idp/oauth2/connect/jwk_uri", "authorizationUrl": "https://login.int.swissid.ch:443/idp/oauth2/authorize", "clientAuthMethod": "client_secret_post", "syncMode": "FORCE", "defaultScope": "openid profile email address" }'
# mappers
MAPPER_ID=$(createIdentityProviderMapper $REALM_NAME $IDENTITY_PROVIDER_ALIAS "given_name -> firstName" oidc-user-attribute-idp-mapper)
$KCADM update identity-provider/instances/$IDENTITY_PROVIDER_ALIAS/mappers/$MAPPER_ID -r $REALM_NAME -s 'config={"syncMode": "INHERIT", "claim": "given_name",  "user.attribute": "firstName"}'

MAPPER_ID=$(createIdentityProviderMapper $REALM_NAME $IDENTITY_PROVIDER_ALIAS "family_name -> lastName" oidc-user-attribute-idp-mapper)
$KCADM update identity-provider/instances/$IDENTITY_PROVIDER_ALIAS/mappers/$MAPPER_ID -r $REALM_NAME -s 'config={"syncMode": "INHERIT", "claim": "family_name", "user.attribute": "lastName"}'

MAPPER_ID=$(createIdentityProviderMapper $REALM_NAME $IDENTITY_PROVIDER_ALIAS "gender -> gender" oidc-user-attribute-idp-mapper)
$KCADM update identity-provider/instances/$IDENTITY_PROVIDER_ALIAS/mappers/$MAPPER_ID -r $REALM_NAME -s 'config={"syncMode": "INHERIT", "claim": "gender",      "user.attribute": "gender"}'

MAPPER_ID=$(createIdentityProviderMapper $REALM_NAME $IDENTITY_PROVIDER_ALIAS "language -> language" oidc-user-attribute-idp-mapper)
$KCADM update identity-provider/instances/$IDENTITY_PROVIDER_ALIAS/mappers/$MAPPER_ID -r $REALM_NAME -s 'config={"syncMode": "INHERIT", "claim": "language",    "user.attribute": "language"}'

#############
# authentication
# in the `browser` flow the identity provider redirector is set as default (= no login screen should be displayed)
EXECUTION_ID=$(getExecution $REALM_NAME browser identity-provider-redirector)
$KCADM create authentication/executions/$EXECUTION_ID/config -r $REALM_NAME -b '{"config":{"defaultProvider":"'$IDENTITY_PROVIDER_ALIAS'"},"alias":"'$IDENTITY_PROVIDER_ALIAS'"}'
