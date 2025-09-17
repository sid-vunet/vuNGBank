# VuBank Multi-Service Architecture

## Quick Start

### Prerequisites
- Docker and Docker Compose installed
- Node.js 18+ (for local frontend development)

### Start All Services
```bash
# Start backend services only
docker-compose up -d

# Start with frontend included
docker-compose --profile frontend up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### Service URLs
- **Frontend**: http://localhost:3000 (if using Docker)
- **Login Gateway**: http://localhost:8000
- **Python Authenticator**: http://localhost:8001
- **Accounts Service**: http://localhost:8002
- **PostgreSQL**: localhost:5432

### Test Credentials
| Username | Password | Role |
|----------|----------|------|
| johndoe | password123 | retail |
| janedoe | password123 | retail |
| corpuser | password123 | corporate |

## Architecture Overview

```
Frontend (React) → Login Gateway (Go) → Python Auth + Accounts Service (Go)
                                     ↓
                                PostgreSQL Database
```

### Service Responsibilities

1. **login-go-service** (Port 8000)
   - Public API gateway
   - Header validation
   - JWT token generation
   - Delegates auth to Python service

2. **login-python-authenticator** (Port 8001)
   - Credential verification
   - Password hashing with bcrypt
   - Role management
   - Login audit logging

3. **accounts-go-service** (Port 8002)
   - Account data retrieval
   - Transaction history
   - JWT token validation
   - Protected internal API

4. **PostgreSQL Database** (Port 5432)
   - User credentials and profiles
   - Account and transaction data
   - Role-based access control
   - Audit logs

## Development

### Local Development
```bash
# Run frontend locally
cd frontend
npm start

# Frontend will connect to containerized backend services
```

### Environment Variables
All services read configuration from environment variables:
- `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `DB_SSLMODE`
- `AUTH_SERVICE_URL`, `ACCOUNTS_SERVICE_URL`
- `JWT_SECRET`, `API_CLIENT`, `PUBLIC_API_PORT`

### Service Health Checks
- All services provide `/health` endpoints
- Docker Compose includes health checks
- Services wait for dependencies to be healthy

### Security Features
- Header validation in gateway
- JWT tokens with 15-minute expiry
- Role-based access control
- Bcrypt password hashing
- Request correlation IDs
- Comprehensive audit logging

## API Documentation

### Login Flow
1. Frontend → `POST /api/login` → Login Gateway
2. Login Gateway → `POST /verify` → Python Auth
3. On success → JWT token generated
4. Frontend uses JWT → `GET /internal/accounts` → Accounts Service

### Required Headers
```
Origin: http://localhost:3000
X-Requested-With: XMLHttpRequest
X-Api-Client: web-portal
Authorization: Bearer <jwt-token>  (for protected endpoints)
```