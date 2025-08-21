# Ballerina API Gateway

A comprehensive API Gateway system built with Ballerina that provides developer management, API key creation, quota management, and proxying to a RAG Moderation Python service.

## Features

- **Developer Management**: Registration, authentication, and account management
- **API Key Management**: Generate, manage, and revoke API keys with quotas
- **Quota Management**: Monthly request limits with automatic reset
- **Rate Limiting**: Per-minute request limits with burst handling
- **Rule Management**: Create and manage moderation rules
- **Analytics**: Request logging and usage analytics
- **Developer Portal**: Next.js web interface for developers

## Architecture

The system consists of three main components:

1. **Ballerina Gateway Service** - Core API gateway with authentication and proxying
2. **Next.js Developer Portal** - Web interface for developer account management
3. **PostgreSQL Database** - Persistent storage for developers, API keys, and analytics

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Ballerina 2201.8.0 or later (for local development)
- Node.js 18+ (for portal development)

### Using Docker Compose (Recommended)

1. Clone the repository
2. Copy environment variables:
   ```bash
   cp .env.example .env
   ```
3. Start all services:
   ```bash
   docker-compose up -d
   ```

This will start:
- PostgreSQL database on port 5432
- Ballerina Gateway on port 8080
- Next.js Portal on port 3000
- Mock Python service on port 8001
- pgAdmin on port 5050 (optional, use `--profile tools`)

### Manual Setup

#### Database Setup

1. Start PostgreSQL:
   ```bash
   docker-compose up -d postgres
   ```

2. Initialize the database:
   ```bash
   psql -h localhost -U gateway_user -d gateway_db -f database/schema.sql
   ```

#### Gateway Service

1. Navigate to the gateway directory:
   ```bash
   cd ballerina-gateway
   ```

2. Build and run:
   ```bash
   bal build
   bal run
   ```

#### Developer Portal

1. Navigate to the portal directory:
   ```bash
   cd user-portal
   ```

2. Install dependencies and start:
   ```bash
   npm install
   npm run dev
   ```

## API Endpoints

### Developer Portal Endpoints (`/portal`)

- `POST /portal/register` - Developer registration
- `POST /portal/login` - Developer login
- `GET /portal/api-keys` - List API keys
- `POST /portal/api-keys` - Create API key
- `DELETE /portal/api-keys/{keyId}` - Delete API key

### Moderation API Endpoints (`/api/v1`)

- `POST /api/v1/moderation/moderate` - Moderate content
- `POST /api/v1/moderation/add-rule` - Add moderation rule
- `GET /api/v1/rules/{apiKey}` - Get rules for API key
- `DELETE /api/v1/rules/{ruleId}` - Delete rule

### Health Check

- `GET /health` - Service health check

## Configuration

The application uses environment variables for configuration. See `.env.example` for all available options.

Key configuration areas:
- Database connection settings
- JWT token configuration
- Python service integration
- Rate limiting parameters

## Development

### Project Structure

```
├── ballerina-gateway/          # Ballerina API Gateway service
│   ├── modules/
│   │   ├── types/             # Data types and models
│   │   ├── config/            # Configuration management
│   │   └── database/          # Database utilities
│   ├── main.bal               # Main entry point
│   └── Ballerina.toml         # Project configuration
├── user-portal/               # Next.js developer portal
├── database/                  # Database schema and migrations
├── mock-services/             # Mock services for development
└── docker-compose.yml         # Docker orchestration
```

### Running Tests

```bash
# Ballerina tests
cd ballerina-gateway
bal test

# Portal tests
cd user-portal
npm test
```

### Database Management

Access pgAdmin at http://localhost:5050 (admin@gateway.local / admin) to manage the database.

## API Key Format

API keys follow the format: `bal_{env}_{year}_{random}`

Example: `bal_dev_2025_a1b2c3d4e5f6g7h8`

## Quota Management

- Default quota: 100 requests per month per API key
- Rate limit: 10 requests per minute with 20 request burst
- Quotas reset automatically on the first day of each month

## Security

- JWT-based authentication for developer portal
- API key validation for moderation endpoints
- SQL injection prevention
- Input validation and sanitization
- Rate limiting and quota enforcement

## Monitoring

The system includes:
- Request logging and analytics
- Health check endpoints
- Error tracking and reporting
- Performance metrics collection

## License

[Add your license information here]