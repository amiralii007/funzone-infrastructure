#!/bin/bash

# FunZone Docker Setup and Run Script for Ubuntu
# This script automatically detects server IP, generates SECRET_KEY, creates .env file, and runs Docker

set -e  # Exit on error

echo "=========================================="
echo "FunZone Docker Setup and Run Script"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check if Docker is installed
echo "Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed!"
    echo "Please install Docker first:"
    echo "  curl -fsSL https://get.docker.com -o get-docker.sh"
    echo "  sudo sh get-docker.sh"
    exit 1
fi
print_success "Docker is installed"

# Check if Docker Compose is installed
echo "Checking Docker Compose installation..."
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    print_error "Docker Compose is not installed!"
    echo "Please install Docker Compose first"
    exit 1
fi
print_success "Docker Compose is installed"

# Detect server IP address
echo ""
echo "Detecting server IP address..."
SERVER_IP=""

# Try different methods to get IP
if command -v hostname &> /dev/null; then
    # Try to get IP from hostname
    SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null)
fi

if [ -z "$SERVER_IP" ]; then
    # Try ip command
    SERVER_IP=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}' 2>/dev/null)
fi

if [ -z "$SERVER_IP" ]; then
    # Try ifconfig
    SERVER_IP=$(ifconfig 2>/dev/null | grep -oP 'inet \K[\d.]+' | grep -v '127.0.0.1' | head -1)
fi

if [ -z "$SERVER_IP" ]; then
    print_warning "Could not automatically detect server IP"
    read -p "Please enter your server IP address: " SERVER_IP
else
    print_success "Detected server IP: $SERVER_IP"
fi

# Generate SECRET_KEY if not exists
echo ""
echo "Generating SECRET_KEY..."
if [ -f .env ] && grep -q "SECRET_KEY=" .env && ! grep -q "your-super-secret-key-change-in-production" .env; then
    print_success "SECRET_KEY already exists in .env file"
else
    # Generate a secure random SECRET_KEY
    SECRET_KEY=$(openssl rand -base64 64 | tr -d '\n' | tr -d '=' | cut -c1-50)
    print_success "Generated new SECRET_KEY"
fi

# Create or update .env file
echo ""
echo "Creating/updating .env file..."

if [ ! -f .env ]; then
    # Create new .env from env.example if it exists
    if [ -f env.example ]; then
        cp env.example .env
        print_success "Created .env from env.example"
    else
        # Create .env from scratch
        cat > .env << EOF
# Django Backend
SECRET_KEY=$SECRET_KEY
DEBUG=False

# Database
POSTGRES_DB=funzone_db
POSTGRES_USER=funzone_user
POSTGRES_PASSWORD=funzone_password

# MongoDB
MONGO_USER=mongo_user
MONGO_PASSWORD=mongo_password

# API Base URL (for frontend builds)
VITE_API_BASE_URL=http://$SERVER_IP/api

# Server IP
SERVER_IP=$SERVER_IP
EOF
        print_success "Created new .env file"
    fi
else
    print_success ".env file already exists"
fi

# Update SECRET_KEY in .env if needed
if grep -q "your-super-secret-key-change-in-production" .env || ! grep -q "SECRET_KEY=" .env; then
    if [ -z "$SECRET_KEY" ]; then
        SECRET_KEY=$(openssl rand -base64 64 | tr -d '\n' | tr -d '=' | cut -c1-50)
    fi
    if grep -q "SECRET_KEY=" .env; then
        sed -i "s|SECRET_KEY=.*|SECRET_KEY=$SECRET_KEY|" .env
    else
        echo "SECRET_KEY=$SECRET_KEY" >> .env
    fi
    print_success "Updated SECRET_KEY in .env"
fi

# Update VITE_API_BASE_URL with server IP
if grep -q "VITE_API_BASE_URL=" .env; then
    sed -i "s|VITE_API_BASE_URL=.*|VITE_API_BASE_URL=http://$SERVER_IP/api|" .env
    print_success "Updated VITE_API_BASE_URL with server IP"
fi

# Add SERVER_IP to .env if not present
if ! grep -q "SERVER_IP=" .env; then
    echo "SERVER_IP=$SERVER_IP" >> .env
    print_success "Added SERVER_IP to .env"
fi

# Display .env file (without sensitive data)
echo ""
echo "=========================================="
echo ".env file configuration:"
echo "=========================================="
grep -v "PASSWORD\|SECRET_KEY" .env | sed 's/=.*/=***HIDDEN***/'
echo "SECRET_KEY=***HIDDEN***"
grep "PASSWORD" .env | sed 's/=.*/=***HIDDEN***/'
echo "SERVER_IP=$SERVER_IP"
echo ""

# Ask for confirmation
read -p "Do you want to start Docker containers now? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup complete. You can start Docker later with:"
    echo "  docker-compose up -d --build"
    exit 0
fi

# Start Docker containers
echo ""
echo "=========================================="
echo "Starting Docker containers..."
echo "=========================================="
echo ""

# Check if docker-compose or docker compose
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    COMPOSE_CMD="docker compose"
fi

# Build and start containers
$COMPOSE_CMD up -d --build

echo ""
echo "=========================================="
echo "Docker containers started!"
echo "=========================================="
echo ""
echo "Server Information:"
echo "  IP Address: $SERVER_IP"
echo "  Frontend Customer: http://$SERVER_IP"
echo "  Frontend Owner: http://$SERVER_IP/owner"
echo "  Backend API: http://$SERVER_IP/api"
echo "  Admin Panel: http://$SERVER_IP/admin"
echo ""
echo "To view logs:"
echo "  $COMPOSE_CMD logs -f"
echo ""
echo "To stop containers:"
echo "  $COMPOSE_CMD down"
echo ""
echo "To restart containers:"
echo "  $COMPOSE_CMD restart"
echo ""
