# Deployment Steps

1. To re-generate ZITADEL_MASTERKEY and LOGIN_SESSION_COOKIE_SECRET
`openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 32; echo`
