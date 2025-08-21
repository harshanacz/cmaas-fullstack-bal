# Makefile for Ballerina API Gateway

.PHONY: help build start stop clean test logs db-init

# Default target
help:
	@echo "Available commands:"
	@echo "  build     - Build all services"
	@echo "  start     - Start all services with Docker Compose"
	@echo "  stop      - Stop all services"
	@echo "  clean     - Clean up containers and volumes"
	@echo "  test      - Run tests"
	@echo "  logs      - Show logs from all services"
	@echo "  db-init   - Initialize database schema"
	@echo "  dev       - Start development environment"

# Build all services
build:
	docker-compose build

# Start all services
start:
	docker-compose up -d

# Stop all services
stop:
	docker-compose down

# Clean up everything
clean:
	docker-compose down -v --remove-orphans
	docker system prune -f

# Run tests
test:
	cd ballerina-gateway && bal test
	cd user-portal && npm test

# Show logs
logs:
	docker-compose logs -f

# Initialize database
db-init:
	docker-compose up -d postgres
	@echo "Waiting for PostgreSQL to be ready..."
	@sleep 10
	docker-compose exec postgres psql -U gateway_user -d gateway_db -f /docker-entrypoint-initdb.d/02-schema.sql

# Development environment
dev:
	@echo "Starting development environment..."
	docker-compose up -d postgres python-service
	@echo "Database and mock services started. You can now run the gateway and portal locally."
	@echo ""
	@echo "To run the gateway:"
	@echo "  cd ballerina-gateway && bal run"
	@echo ""
	@echo "To run the portal:"
	@echo "  cd user-portal && npm run dev"

# Check service health
health:
	@echo "Checking service health..."
	@curl -f http://localhost:8080/health || echo "Gateway: DOWN"
	@curl -f http://localhost:3000 || echo "Portal: DOWN"
	@docker-compose exec postgres pg_isready -U gateway_user -d gateway_db || echo "Database: DOWN"