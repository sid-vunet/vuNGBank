# VuNG Bank Service Management

## Quick Start

```bash
# Check status of all services
./manage-services.sh status

# Start all services
./manage-services.sh start

# Stop all services  
./manage-services.sh stop

# Restart all services
./manage-services.sh restart

# Health check all services
./manage-services.sh health
```

## Commands

| Command | Description |
|---------|-------------|
| `status` | Check status of all services |
| `start` | Start all services (Docker containers) |
| `stop` | Stop all services |
| `restart` | Restart all services |
| `clean` | Clean up all Docker images and containers |
| `install` | Perform fresh installation (clean + build + start) |
| `logs` | Show recent logs from all services |
| `health` | Perform health checks on all endpoints |

## Container Services

All services run as Docker containers for consistent deployment:

- **Frontend**: http://localhost:3000 (React App Container) [optional - use profile]  
- **Login Gateway**: http://localhost:8000 (Go Service Container)
- **Auth Service**: http://localhost:8001 (Python FastAPI Container)
- **Accounts Service**: http://localhost:8002 (Go Service Container)
- **PDF Service**: http://localhost:8003 (Java Spring Boot Container)
- **Payee Service**: http://localhost:5004 (.NET Service Container)
- **Database**: localhost:5432 (PostgreSQL Container)

## Manual Frontend (Alternative)

If you prefer running frontend locally:

```bash
cd frontend
npm install
npm start  # Runs on localhost:3001
```

## Test Credentials

| Username | Password | Role |
|----------|----------|------|
| johndoe | password123 | retail |
| janedoe | password123 | retail |
| corpuser | password123 | corporate |

## Deployment Architecture

All services are containerized using Docker Compose:

```yaml
# Start all backend services
docker-compose up -d

# Start with frontend container (optional)
docker-compose --profile frontend up -d
```

## Troubleshooting

### Services not starting?
```bash
./manage-services.sh clean
./manage-services.sh install
```

### Individual service rebuild?
```bash
# Rebuild specific service
docker-compose build login-go-service
docker-compose up login-go-service -d
```

### Check logs for errors?
```bash
./manage-services.sh logs
# OR specific service
docker-compose logs login-go-service --tail=20
```

## Session Management & Logout

### Complete Logout Flow
1. Frontend calls `/api/logout` endpoint
2. Go gateway forwards to Python auth service `/logout`
3. Active sessions terminated in database  
4. Frontend localStorage cleared
5. User redirected to login page

### Testing Session Management
1. Login with any user
2. Open new tab, try to login with same user  
3. See session conflict dialog
4. Click "Continue" to force login and terminate previous session
5. Logout properly terminates all sessions (no more conflicts)

## Observability Stack

- **APM Server**: http://91.203.133.240:30200
- **Backend Instrumentation**: Elastic APM Go agent on login service
- **Frontend Monitoring**: Elastic RUM on all pages
- **Distributed Tracing**: End-to-end trace correlation between frontend and backend

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│   Frontend      │───▶│  Go Login        │───▶│  Python Auth     │
│   (React)       │    │  Gateway :8000   │    │  Service :8001   │
│   :3000/3001    │    └──────────────────┘    └──────────────────┘
└─────────────────┘             │                       │
                                │                       ▼
                    ┌──────────────────┐    ┌──────────────────┐
                    │  Go Accounts     │    │  PostgreSQL      │
                    │  Service :8002   │    │  Database :5432  │
                    └──────────────────┘    └──────────────────┘
                                │                       ▲
                    ┌──────────────────┐                │
                    │  Java PDF        │                │
                    │  Service :8003   │                │
                    └──────────────────┘                │
                                │                       │
                    ┌──────────────────┐                │
                    │  .NET Payee      │                │
                    │  Service :5004   │────────────────┘
                    └──────────────────┘
```