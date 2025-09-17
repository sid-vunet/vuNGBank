# VuBank NextGen Banking Platform - System Architecture

## Overview

VuBank NextGen is a full-stack banking simulation platform that mimics Standard Chartered Bank's Straight2Bank interface. The system uses a microservices architecture with synthetic data for demonstration and testing purposes.

## High-Level Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│   Frontend      │───▶│  Go Login        │───▶│  Python Auth     │
│   (React)       │    │  Gateway :8000   │    │  Service :8001   │
│   :3001         │    └──────────────────┘    └──────────────────┘
└─────────────────┘             │                        │
                                ▼                        ▼
                    ┌──────────────────┐    ┌──────────────────┐
                    │  Go Accounts     │    │  PostgreSQL      │
                    │  Service :8002   │    │  Database :5432  │
                    └──────────────────┘    └──────────────────┘
```

## Components

### Frontend Layer
- **Technology**: React 18.2.0 with hooks
- **Port**: 3001 (development), 3000 (containerized)
- **Purpose**: User interface mimicking SCB Straight2Bank design
- **Key Features**:
  - Responsive banking dashboard
  - Session conflict handling
  - JWT token management
  - Real-time error handling

### API Gateway Layer
- **Service**: login-go-service
- **Technology**: Go with Gin framework
- **Port**: 8000
- **Purpose**: Public API gateway and JWT token generation
- **Responsibilities**:
  - Header validation and security
  - Request routing and proxying
  - JWT token creation and management
  - Session conflict resolution

### Authentication Service
- **Service**: login-python-authenticator
- **Technology**: Python FastAPI
- **Port**: 8001
- **Purpose**: User authentication and session management
- **Responsibilities**:
  - Credential verification with bcrypt
  - Session lifecycle management
  - Login attempt auditing
  - Role-based access control

### Account Service
- **Service**: accounts-go-service
- **Technology**: Go with Gin framework
- **Port**: 8002
- **Purpose**: Account data and transaction management
- **Responsibilities**:
  - Account balance retrieval
  - Transaction history
  - JWT token validation
  - Protected internal APIs

### Database Layer
- **Technology**: PostgreSQL 15
- **Port**: 5432
- **Purpose**: Persistent data storage
- **Schema**:
  - Users and authentication
  - Account information
  - Transaction records
  - Session management
  - Audit logs

## Service Communication

### Authentication Flow
1. Frontend → Go Gateway (login request)
2. Go Gateway → Python Auth (credential verification)
3. Python Auth → PostgreSQL (user validation)
4. Go Gateway → JWT token generation
5. Frontend ← JWT token response

### Data Flow
1. Frontend → Go Gateway (authenticated requests)
2. Go Gateway → Accounts Service (with JWT)
3. Accounts Service → PostgreSQL (data queries)
4. Response chain back to frontend

## Security Architecture

### Authentication & Authorization
- **JWT Tokens**: 15-minute expiry with HS256 signing
- **Password Hashing**: bcrypt with cost factor 10
- **Session Management**: Single active session per user
- **Role-Based Access**: retail, corporate, admin roles

### API Security
- **Header Validation**: Required headers for all requests
- **CORS Configuration**: Controlled cross-origin access
- **Request Correlation**: Unique IDs for request tracking
- **Audit Logging**: Comprehensive authentication logs

## Deployment Architecture

### Development Environment
- **Frontend**: Local development server (npm start)
- **Backend Services**: Docker Compose orchestration
- **Database**: PostgreSQL container with volume persistence
- **Service Discovery**: Docker network communication

### Container Strategy
- **Multi-stage Builds**: Optimized Docker images
- **Health Checks**: Service availability monitoring
- **Dependency Management**: Proper service startup order
- **Volume Persistence**: Database data retention

## Data Architecture

### Database Schema
```sql
users → user_roles ← roles
  ↓
accounts
  ↓
transactions

active_sessions → users
login_requests → users
```

### Data Flow Patterns
- **Read Operations**: Direct database queries through services
- **Write Operations**: Transactional updates with audit trails
- **Session Data**: In-memory and database hybrid storage
- **Synthetic Data**: Faker.js generated realistic test data

## Scalability Considerations

### Horizontal Scaling
- **Stateless Services**: JWT-based authentication
- **Database Connection Pooling**: Efficient resource usage
- **Container Orchestration**: Docker Compose for development
- **Service Independence**: Microservices architecture

### Performance Optimization
- **Database Indexing**: Optimized query performance
- **Caching Strategy**: JWT tokens and session data
- **Async Operations**: Non-blocking service calls
- **Connection Management**: Proper resource cleanup

## Monitoring & Observability

### Health Checks
- **Service Health**: Dedicated health endpoints
- **Database Connectivity**: Connection validation
- **Dependency Monitoring**: Service availability checks

### Logging Strategy
- **Request Correlation**: Unique request tracking
- **Authentication Audits**: Comprehensive login logs
- **Error Tracking**: Structured error responses
- **Performance Metrics**: Response time monitoring