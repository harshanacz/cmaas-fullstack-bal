# How to Run the Ballerina API Gateway

This guide provides step-by-step instructions for running the Ballerina API Gateway system in different environments.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start with Docker Compose](#quick-start-with-docker-compose)
3. [Manual Setup](#manual-setup)
4. [Development Setup](#development-setup)
5. [Testing the System](#testing-the-system)
6. [Troubleshooting](#troubleshooting)
7. [Configuration](#configuration)

## Prerequisites

### Required Software

- **Docker** (version 20.0 or later)
- **Docker Compose** (version 2.0 or later)

### Optional (for local development)

- **Ballerina** (version 2201.8.0 or later) - [Download here](https://ballerina.io/downloads/)
- **Node.js** (version 18 or later) - [Download here](https://nodejs.org/)
- **PostgreSQL** (version 13 or later) - [Download here](https://www.postgresql.org/download/)

### System Requirements

- **RAM**: Minimum 4GB, Recommended 8GB
- **Storage**: At least 2GB free space
- **Network**: Internet connection for downloading Docker images

## Quick Start with Docker Compose

This is the **recommended** way to run the system for evaluation and development.

### Step 1: Clone and Setup

```bash
# Clone the repository
git clone <repository-url>
cd ballerina-api-gateway

# Copy environment configuration
cp .env.example .env
```

### Step 2: Configure Environment (Optional)

Edit the `.env` file if you want to customize settings:

```bash
# Edit environment variables
nano .env  # or use your preferred editor
```

Key settings you might want to change:
- `JWT_SECRET` - Change this for production
- `DB_PASSWORD` - Change the database password
- `SERVER_PORT` - Change the gateway port (default: 8080)

### Step 3: Start All Services

```bash
# Start all services in the background
docker-compose up -d

# Or start with logs visible
docker-compose up
```

This will start:
- **PostgreSQL Database** on port `5432`
- **Ballerina Gateway** on port `8080`
- **Mock Python Service** on port `8001`
- **Next.js Portal** on port `3000` (when implemented)

### Step 4: Verify Services

```bash
# Check if all services are running
docker-compose ps

# Check service health
curl http://localhost:8080/health
```

### Step 5: Access the System

- **API Gateway**: http://localhost:8080
- **Health Check**: http://localhost:8080/health
- **Mock Python Service**: http://localhost:8001
- **Developer Portal**: http://localhost:3000 (when implemented)

## Manual Setup

If you prefer to run services individually or don't want to use Docker.

### Step 1: Setup Database

#### Option A: Using Docker for Database Only

```bash
# Start only PostgreSQL
docker-compose up -d postgres

# Wait for database to be ready
sleep 10

# Initialize schema
docker-compose exec postgres psql -U gateway_user -d gateway_db -f /docker-entrypoint-initdb.d/02-schema.sql
```

#### Option B: Local PostgreSQL Installation

```bash
# Create database and user
sudo -u postgres psql -c "CREATE USER gateway_user WITH PASSWORD 'gateway_pass';"
sudo -u postgres psql -c "CREATE DATABASE gateway_db OWNER gateway_user;"

# Initialize schema
psql -h localhost -U gateway_user -d gateway_db -f database/schema.sql
```

### Step 2: Setup Environment Variables

```bash
# Copy and edit environment file
cp .env.example .env

# Set database connection for local setup
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=gateway_db
export DB_USER=gateway_user
export DB_PASSWORD=gateway_pass
```

### Step 3: Run Ballerina Gateway

```bash
# Navigate to gateway directory
cd ballerina-gateway

# Build the project
bal build

# Run the gateway
bal run
```

### Step 4: Start Mock Python Service (Optional)

```bash
# In a new terminal, start mock service
docker run -p 8001:8080 -v $(pwd)/mock-services/python:/home/wiremock wiremock/wiremock:latest
```

## Development Setup

For active development with hot reloading and debugging.

### Step 1: Start Infrastructure Services

```bash
# Start only database and mock services
make dev

# Or manually:
docker-compose up -d postgres python-service
```

### Step 2: Run Gateway Locally

```bash
# In one terminal
cd ballerina-gateway
bal run --observability-included
```

### Step 3: Run Portal Locally (when implemented)

```bash
# In another terminal
cd user-portal
npm install
npm run dev
```

### Step 4: Development Tools

```bash
# Access database management
docker-compose --profile tools up -d pgadmin
# Access at http://localhost:5050 (admin@gateway.local / admin)

# View logs
make logs

# Run tests
make test
```

## Testing the System

### Health Check

```bash
curl http://localhost:8080/health
```

Expected response:
```json
{
  "status": "healthy",
  "timestamp": "2025-01-21T10:30:00Z",
  "services": {
    "database": "healthy",
    "python_service": "healthy"
  }
}
```

### Developer Registration

```bash
curl -X POST http://localhost:8080/portal/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "developer@example.com",
    "password": "securepassword123"
  }'
```

### Developer Login

```bash
curl -X POST http://localhost:8080/portal/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "developer@example.com",
    "password": "securepassword123"
  }'
```

### Create API Key

```bash
# First login to get JWT token, then:
curl -X POST http://localhost:8080/portal/api-keys \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "name": "My Test API Key"
  }'
```

### Test Moderation API

```bash
# Use the API key from previous step
curl -X POST http://localhost:8080/api/v1/moderation/moderate \
  -H "Content-Type: application/json" \
  -H "X-API-Key: YOUR_API_KEY" \
  -d '{
    "content": "This is test content to moderate"
  }'
```

## Troubleshooting

### Common Issues

#### 1. Port Already in Use

```bash
# Check what's using the port
lsof -i :8080  # or :5432, :3000

# Kill the process or change port in .env file
```

#### 2. Database Connection Failed

```bash
# Check if PostgreSQL is running
docker-compose ps postgres

# Check database logs
docker-compose logs postgres

# Restart database
docker-compose restart postgres
```

#### 3. Ballerina Build Errors

```bash
# Clean and rebuild
cd ballerina-gateway
rm -rf target/
bal clean
bal build
```

#### 4. Docker Issues

```bash
# Clean up Docker resources
docker-compose down -v
docker system prune -f

# Rebuild images
docker-compose build --no-cache
```

### Checking Service Status

```bash
# Check all services
docker-compose ps

# Check specific service logs
docker-compose logs gateway
docker-compose logs postgres

# Check resource usage
docker stats
```

### Database Access

```bash
# Connect to database directly
docker-compose exec postgres psql -U gateway_user -d gateway_db

# Or use pgAdmin at http://localhost:5050
docker-compose --profile tools up -d pgadmin
```

## Configuration

### Environment Variables

Key configuration options in `.env`:

```bash
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=gateway_db
DB_USER=gateway_user
DB_PASSWORD=gateway_pass

# Security
JWT_SECRET=your-super-secret-jwt-key-change-in-production
JWT_EXPIRATION=3600

# Rate Limiting
RATE_LIMIT_PER_MINUTE=10
RATE_LIMIT_BURST=20

# External Services
PYTHON_SERVICE_URL=http://localhost:8001
```

### Production Considerations

For production deployment:

1. **Change default passwords** in `.env`
2. **Use strong JWT secret** (at least 32 characters)
3. **Enable SSL/TLS** for all endpoints
4. **Set up proper monitoring** and logging
5. **Configure backup** for PostgreSQL
6. **Use environment-specific** Docker Compose files
7. **Set resource limits** in Docker Compose

### Scaling

To scale the gateway service:

```bash
# Scale to 3 instances
docker-compose up -d --scale gateway=3

# Use a load balancer (nginx, traefik, etc.)
```

## Useful Commands

```bash
# Start everything
make start

# Stop everything
make stop

# View logs
make logs

# Clean up
make clean

# Run tests
make test

# Check health
make health

# Development mode
make dev
```

## Next Steps

After successfully running the system:

1. **Implement remaining tasks** from the specification
2. **Add the Next.js developer portal**
3. **Integrate with real Python moderation service**
4. **Add monitoring and observability**
5. **Set up CI/CD pipeline**
6. **Configure production deployment**

For more detailed information, see the main [README.md](README.md) file.