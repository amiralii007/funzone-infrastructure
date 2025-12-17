# FunZone Infrastructure Repository

This repository contains Docker Compose configurations and infrastructure setup for the FunZone application ecosystem.

## 📦 Repository Structure

```
funzone-infrastructure/
├── docker-compose.yml          # Production Docker Compose
├── docker-compose.dev.yml      # Development Docker Compose
├── nginx/                      # Nginx configuration
│   ├── Dockerfile
│   └── nginx.conf
├── scripts/                    # Utility scripts
│   └── 01-restore-backup.sh
├── data/                       # Database backups (gitignored)
└── backups/                    # Automated backups (gitignored)
```

## 🏗️ Architecture

This infrastructure orchestrates the following services:

- **Backend**: Django REST API (`funzone-backend` repository)
- **Frontend Customer**: React app for customers (`funzone-frontend-customer` repository)
- **Frontend Owner**: React app for venue owners (`funzone-frontend-owner` repository)
- **Database**: PostgreSQL 16
- **Cache**: Redis 7
- **Logging**: MongoDB 7
- **Reverse Proxy**: Nginx

## 🚀 Quick Start

### Prerequisites

1. **Clone all required repositories** in the same parent directory:
   ```bash
   parent-directory/
   ├── funzone-backend/
   ├── funzone-frontend-customer/
   ├── funzone-frontend-owner/
   └── funzone-infrastructure/  # This repo
   ```

2. **Install Docker and Docker Compose**

3. **Set up environment variables**:
   ```bash
   cp env.example .env
   # Edit .env with your configuration
   ```

### Development Setup

```bash
# Start all services in development mode
docker-compose -f docker-compose.dev.yml up --build

# Services will be available at:
# - Backend API: http://localhost:8888/api
# - Customer App: http://localhost:3002
# - Owner App: http://localhost:3003
# - PostgreSQL: localhost:5433
# - Redis: localhost:6380
# - MongoDB: localhost:27018
```

### Production Setup

```bash
# Start all services in production mode
docker-compose up -d --build

# Services will be available at:
# - Nginx (with all apps): http://localhost
# - Backend API: http://localhost/api
# - Customer App: http://localhost
# - Owner App: http://localhost/owner
```

## 📋 Environment Variables

Create a `.env` file with the following variables:

```env
# Django Backend
SECRET_KEY=your-super-secret-key-change-in-production
DEBUG=False

# Database
POSTGRES_DB=funzone_db
POSTGRES_USER=funzone_user
POSTGRES_PASSWORD=funzone_password

# MongoDB
MONGO_USER=mongo_user
MONGO_PASSWORD=mongo_password

# API Base URL (for frontend builds)
VITE_API_BASE_URL=http://localhost/api
```

## 🔧 Repository Setup Options

### Option 1: Git Submodules (Recommended)

```bash
# In the infrastructure repository
git submodule add <backend-repo-url> ../funzone-backend
git submodule add <customer-frontend-repo-url> ../funzone-frontend-customer
git submodule add <owner-frontend-repo-url> ../funzone-frontend-owner

# Update submodules
git submodule update --init --recursive
```

### Option 2: Sibling Directories

Simply clone all repositories as siblings in the same parent directory.

### Option 3: Docker Images from Registry

If you publish Docker images to a registry, update `docker-compose.yml` to use images instead of build contexts:

```yaml
services:
  backend:
    image: registry.example.com/funzone-backend:latest
    # Remove build section
```

## 📁 Directory Structure Requirements

The Docker Compose files expect the following structure:

```
parent-directory/
├── funzone-backend/              # Backend repository
│   ├── Dockerfile
│   └── ...
├── funzone-frontend-customer/    # Customer frontend repository
│   ├── Dockerfile
│   └── ...
├── funzone-frontend-owner/       # Owner frontend repository
│   ├── Dockerfile
│   └── ...
└── funzone-infrastructure/       # This repository
    ├── docker-compose.yml
    └── ...
```

If your structure is different, update the `build.context` paths in the Docker Compose files.

## 🗄️ Database Management

### Initial Database Setup

Place your database backup file at:
```
infrastructure/data/FunZoneApp.backup
```

The database will be automatically restored on first initialization.

### Manual Backup

```bash
docker exec funzone_postgres pg_dump -U funzone_user funzone_db > backups/manual-backup-$(date +%Y%m%d_%H%M%S).sql
```

### Manual Restore

```bash
docker exec -i funzone_postgres psql -U funzone_user funzone_db < backups/backup-file.sql
```

## 🔍 Health Checks

All services include health checks. Check service status:

```bash
docker-compose ps
```

## 🐛 Troubleshooting

### Services won't start

1. Check if ports are already in use:
   ```bash
   # Windows
   netstat -ano | findstr :5433
   
   # Linux/Mac
   lsof -i :5433
   ```

2. Check Docker logs:
   ```bash
   docker-compose logs backend
   docker-compose logs frontend-customer
   ```

### Database connection issues

1. Ensure database is healthy:
   ```bash
   docker-compose ps db
   ```

2. Check database logs:
   ```bash
   docker-compose logs db
   ```

### Frontend can't connect to backend

1. Check `VITE_API_BASE_URL` environment variable
2. Ensure CORS is configured in backend settings
3. Check network connectivity between containers

## 📚 Related Repositories

- [funzone-backend](https://git.zoneco.org/development/funzone-backend) - Django REST API
- [funzone-frontend-customer](https://git.zoneco.org/development/funzone-frontend-customer) - Customer React App
- [funzone-frontend-owner](https://git.zoneco.org/development/funzone-frontend-owner) - Owner React App

## 🤝 Contributing

When updating infrastructure:

1. Test changes in development mode first
2. Update documentation
3. Ensure all services have proper health checks
4. Test database migrations and backups

## 📄 License

[Your License]

