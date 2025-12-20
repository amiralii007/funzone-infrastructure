#!/bin/bash

# Script to obtain Let's Encrypt SSL certificates for FunZone
# Usage: ./scripts/get-ssl-certificates.sh your-email@example.com

set -e

EMAIL=$1
DOMAINS="zone-co.ir www.zone-co.ir beta.zoneco.org"

if [ -z "$EMAIL" ]; then
    echo "Error: Email address is required"
    echo "Usage: ./scripts/get-ssl-certificates.sh your-email@example.com"
    exit 1
fi

echo "Obtaining SSL certificates for: $DOMAINS"
echo "Email: $EMAIL"
echo ""

# Create certbot webroot directory if it doesn't exist
mkdir -p nginx/certbot-webroot

# Make sure nginx is running
echo "Starting nginx..."
docker-compose up -d nginx

# Wait for nginx to be ready
echo "Waiting for nginx to be ready..."
sleep 5

# Obtain certificates
echo "Requesting certificates from Let's Encrypt..."
docker-compose run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    --force-renewal \
    -d zone-co.ir \
    -d www.zone-co.ir \
    -d beta.zoneco.org

echo ""
echo "✅ Certificates obtained successfully!"
echo ""
echo "Next steps:"
echo "1. Uncomment the HTTP to HTTPS redirect in nginx.conf (line with 'return 301 https://')"
echo "2. Reload nginx: docker-compose restart nginx"
echo "3. Your site will now redirect all HTTP traffic to HTTPS"
