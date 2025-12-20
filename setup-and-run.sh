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

# Check if we can write to the current directory
if [ ! -w . ]; then
    print_warning "Cannot write to current directory. Will use sudo for file operations if needed."
    if [ -f .env ] && [ ! -w .env ]; then
        print_warning ".env file exists but is not writable (possibly owned by root)"
        echo "Attempting to fix permissions..."
        sudo chown $USER:$USER .env 2>/dev/null || {
            print_warning "Could not change ownership of .env file, will use sudo for updates"
        }
        if [ -w .env ]; then
            print_success "Fixed .env file permissions"
        fi
    fi
fi

if [ ! -f .env ]; then
    # Create new .env from env.example if it exists
    if [ -f env.example ]; then
        if cp env.example .env 2>/dev/null; then
            print_success "Created .env from env.example"
        else
            print_error "Failed to create .env file (permission denied)"
            echo "Trying with sudo..."
            sudo cp env.example .env && sudo chown $USER:$USER .env
            print_success "Created .env from env.example (with sudo)"
        fi
    else
        # Create .env from scratch
        if cat > .env << EOF
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

# Django ALLOWED_HOSTS (include server IP)
ALLOWED_HOSTS=localhost,127.0.0.1,0.0.0.0,$SERVER_IP,backend,frontend-customer,frontend-owner,nginx

# Frontend URLs for payment callbacks
FRONTEND_URL=http://$SERVER_IP
OWNER_FRONTEND_URL=http://$SERVER_IP/owner
EOF
        then
            print_success "Created new .env file"
        else
            print_error "Failed to create .env file (permission denied)"
            echo "Trying with sudo..."
            sudo tee .env > /dev/null << EOF
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

# Django ALLOWED_HOSTS (include server IP)
ALLOWED_HOSTS=localhost,127.0.0.1,0.0.0.0,$SERVER_IP,backend,frontend-customer,frontend-owner,nginx

# Frontend URLs for payment callbacks
FRONTEND_URL=http://$SERVER_IP
OWNER_FRONTEND_URL=http://$SERVER_IP/owner
EOF
            sudo chown $USER:$USER .env
            print_success "Created new .env file (with sudo)"
        fi
    fi
else
    print_success ".env file already exists"
    # Ensure we can write to it
    if [ ! -w .env ]; then
        print_warning ".env file is not writable, fixing permissions..."
        sudo chown $USER:$USER .env 2>/dev/null || {
            print_error "Could not change ownership of .env file"
            echo "Please run: sudo chown $USER:$USER .env"
            exit 1
        }
        print_success "Fixed .env file permissions"
    fi
fi

# Update SECRET_KEY in .env if needed
if grep -q "your-super-secret-key-change-in-production" .env || ! grep -q "SECRET_KEY=" .env; then
    if [ -z "$SECRET_KEY" ]; then
        SECRET_KEY=$(openssl rand -base64 64 | tr -d '\n' | tr -d '=' | cut -c1-50)
    fi
    if grep -q "SECRET_KEY=" .env; then
        if sed -i "s|SECRET_KEY=.*|SECRET_KEY=$SECRET_KEY|" .env 2>/dev/null; then
            print_success "Updated SECRET_KEY in .env"
        else
            print_warning "Could not update SECRET_KEY directly, trying with sudo..."
            sudo sed -i "s|SECRET_KEY=.*|SECRET_KEY=$SECRET_KEY|" .env && sudo chown $USER:$USER .env
            print_success "Updated SECRET_KEY in .env (with sudo)"
        fi
    else
        if echo "SECRET_KEY=$SECRET_KEY" >> .env 2>/dev/null; then
            print_success "Added SECRET_KEY to .env"
        else
            print_warning "Could not append SECRET_KEY, trying with sudo..."
            echo "SECRET_KEY=$SECRET_KEY" | sudo tee -a .env > /dev/null && sudo chown $USER:$USER .env
            print_success "Added SECRET_KEY to .env (with sudo)"
        fi
    fi
fi

# Update VITE_API_BASE_URL with server IP
if grep -q "VITE_API_BASE_URL=" .env; then
    if sed -i "s|VITE_API_BASE_URL=.*|VITE_API_BASE_URL=http://$SERVER_IP/api|" .env 2>/dev/null; then
        print_success "Updated VITE_API_BASE_URL with server IP"
    else
        print_warning "Could not update VITE_API_BASE_URL directly, trying with sudo..."
        sudo sed -i "s|VITE_API_BASE_URL=.*|VITE_API_BASE_URL=http://$SERVER_IP/api|" .env && sudo chown $USER:$USER .env
        print_success "Updated VITE_API_BASE_URL with server IP (with sudo)"
    fi
fi

# Add SERVER_IP to .env if not present
if ! grep -q "SERVER_IP=" .env; then
    if echo "SERVER_IP=$SERVER_IP" >> .env 2>/dev/null; then
        print_success "Added SERVER_IP to .env"
    else
        print_warning "Could not append SERVER_IP, trying with sudo..."
        echo "SERVER_IP=$SERVER_IP" | sudo tee -a .env > /dev/null && sudo chown $USER:$USER .env
        print_success "Added SERVER_IP to .env (with sudo)"
    fi
fi

# Update FRONTEND_URL with server IP
if grep -q "FRONTEND_URL=" .env; then
    if sed -i "s|FRONTEND_URL=.*|FRONTEND_URL=http://$SERVER_IP|" .env 2>/dev/null; then
        print_success "Updated FRONTEND_URL with server IP"
    else
        print_warning "Could not update FRONTEND_URL directly, trying with sudo..."
        sudo sed -i "s|FRONTEND_URL=.*|FRONTEND_URL=http://$SERVER_IP|" .env && sudo chown $USER:$USER .env
        print_success "Updated FRONTEND_URL with server IP (with sudo)"
    fi
else
    # Add FRONTEND_URL if not present
    if echo "FRONTEND_URL=http://$SERVER_IP" >> .env 2>/dev/null; then
        print_success "Added FRONTEND_URL to .env"
    else
        print_warning "Could not append FRONTEND_URL, trying with sudo..."
        echo "FRONTEND_URL=http://$SERVER_IP" | sudo tee -a .env > /dev/null && sudo chown $USER:$USER .env
        print_success "Added FRONTEND_URL to .env (with sudo)"
    fi
fi

# Update OWNER_FRONTEND_URL with server IP
if grep -q "OWNER_FRONTEND_URL=" .env; then
    if sed -i "s|OWNER_FRONTEND_URL=.*|OWNER_FRONTEND_URL=http://$SERVER_IP/owner|" .env 2>/dev/null; then
        print_success "Updated OWNER_FRONTEND_URL with server IP"
    else
        print_warning "Could not update OWNER_FRONTEND_URL directly, trying with sudo..."
        sudo sed -i "s|OWNER_FRONTEND_URL=.*|OWNER_FRONTEND_URL=http://$SERVER_IP/owner|" .env && sudo chown $USER:$USER .env
        print_success "Updated OWNER_FRONTEND_URL with server IP (with sudo)"
    fi
else
    # Add OWNER_FRONTEND_URL if not present
    if echo "OWNER_FRONTEND_URL=http://$SERVER_IP/owner" >> .env 2>/dev/null; then
        print_success "Added OWNER_FRONTEND_URL to .env"
    else
        print_warning "Could not append OWNER_FRONTEND_URL, trying with sudo..."
        echo "OWNER_FRONTEND_URL=http://$SERVER_IP/owner" | sudo tee -a .env > /dev/null && sudo chown $USER:$USER .env
        print_success "Added OWNER_FRONTEND_URL to .env (with sudo)"
    fi
fi

# Update ALLOWED_HOSTS with server IP
if grep -q "ALLOWED_HOSTS=" .env; then
    CURRENT_HOSTS=$(grep "ALLOWED_HOSTS=" .env | cut -d'=' -f2)
    if [[ "$CURRENT_HOSTS" != *"$SERVER_IP"* ]]; then
        # Add server IP to ALLOWED_HOSTS
        NEW_HOSTS="$CURRENT_HOSTS,$SERVER_IP"
        if sed -i "s|ALLOWED_HOSTS=.*|ALLOWED_HOSTS=$NEW_HOSTS|" .env 2>/dev/null; then
            print_success "Updated ALLOWED_HOSTS with server IP"
        else
            print_warning "Could not update ALLOWED_HOSTS directly, trying with sudo..."
            sudo sed -i "s|ALLOWED_HOSTS=.*|ALLOWED_HOSTS=$NEW_HOSTS|" .env && sudo chown $USER:$USER .env
            print_success "Updated ALLOWED_HOSTS with server IP (with sudo)"
        fi
    else
        print_success "Server IP already in ALLOWED_HOSTS"
    fi
else
    # Add ALLOWED_HOSTS if not present
    if echo "ALLOWED_HOSTS=localhost,127.0.0.1,0.0.0.0,$SERVER_IP" >> .env 2>/dev/null; then
        print_success "Added ALLOWED_HOSTS to .env"
    else
        print_warning "Could not append ALLOWED_HOSTS, trying with sudo..."
        echo "ALLOWED_HOSTS=localhost,127.0.0.1,0.0.0.0,$SERVER_IP" | sudo tee -a .env > /dev/null && sudo chown $USER:$USER .env
        print_success "Added ALLOWED_HOSTS to .env (with sudo)"
    fi
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

# Stop and remove containers first to avoid ContainerConfig errors
echo "Stopping existing containers..."
$COMPOSE_CMD down 2>/dev/null || true

# Remove the problematic backend container if it exists
if docker ps -a --format '{{.Names}}' | grep -q "^funzone_backend$"; then
    echo "Removing old backend container..."
    docker rm -f funzone_backend 2>/dev/null || true
fi

# Build and start containers
echo "Building and starting containers..."
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

