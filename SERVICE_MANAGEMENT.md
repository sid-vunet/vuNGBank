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
| `start` | Start all services (Docker + Frontend) |
| `stop` | Stop all services |
| `restart` | Restart all services |
| `clean` | Clean up all Docker images and containers |
| `install` | Perform fresh installation (clean + build + start) |
| `logs` | Show recent logs from all services |
| `health` | Perform health checks on all endpoints |

## Services

- **Frontend**: http://localhost:3001 (React App)
- **Login API**: http://localhost:8000 (Go Gateway)
- **Auth Service**: http://localhost:8001 (Python FastAPI)
- **Accounts API**: http://localhost:8002 (Go Service)  
- **Database**: localhost:5432 (PostgreSQL)

## Test Credentials

| Username | Password | Role |
|----------|----------|------|
| johndoe | password123 | retail |
| janedoe | password123 | retail |
| corpuser | password123 | corporate |

## Troubleshooting

### Services not starting?
```bash
./manage-services.sh clean
./manage-services.sh install
```

### Frontend connection issues?
```bash
./manage-services.sh restart
./manage-services.sh health
```

### Check logs for errors?
```bash
./manage-services.sh logs
```

## Session Management Testing

1. Login with any user
2. Open new tab, try to login with same user  
3. See session conflict dialog
4. Click "Continue" to force login and terminate previous session

## Architecture

```
┌─────────────────┐    ┌──────────────────┐
│   Frontend      │───▶│  Go Login        │
│   (React)       │    │  Service :8000   │
│   :3001         │    └──────────────────┘
└─────────────────┘             │
                                ▼
                    ┌──────────────────┐
                    │  Python Auth     │
                    │  Service :8001   │
                    └──────────────────┘
                                │
                                ▼
                    ┌──────────────────┐
                    │  PostgreSQL      │
                    │  Database :5432  │
                    └──────────────────┘
```