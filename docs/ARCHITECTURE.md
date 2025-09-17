# VuBank NextGen Banking Platform - System Architecture

## Overview

VuBank NextGen is a full-stack banking simulation platform that mimics Standard Chartered Bank's Straight2Bank interface. The system uses a microservices architecture with synthetic data for demonstration and testing purposes.

# VuBank NextGen Banking Platform - System Architecture

## Overview

VuBank NextGen is a comprehensive banking simulation platform that replicates VuBank's Straight2Bank interface using modern microservices architecture. The system combines HTML/CSS/JS frontend with containerized backend services and synthetic data for complete banking workflow demonstration.

## High-Level Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│   Frontend      │───▶│  Go Login        │───▶│  Python Auth     │
│  (HTML/CSS/JS)  │    │  Gateway :8000   │    │  Service :8001   │
│   :3001         │    └──────────────────┘    └──────────────────┘
└─────────────────┘             │                        │
                                ▼                        ▼
                    ┌──────────────────┐    ┌──────────────────┐
                    │  Go Accounts     │    │  PostgreSQL      │
                    │  Service :8002   │    │  Database :5432  │
                    └──────────────────┘    └──────────────────┘
                                │
                                ▼
                    ┌──────────────────┐
                    │  Java PDF        │
                    │  Service :8003   │
                    └──────────────────┘
```

## Components

## Components

### Frontend Layer
- **Technology**: Pure HTML5, CSS3, and vanilla JavaScript (ES6+)
- **Port**: 3001 (development), served by custom HTTP server
- **Purpose**: Banking interface with VuBank design principles
- **Key Features**:
  - Responsive banking dashboard with real-time data
  - Complete fund transfer workflow with multi-step process
  - PDF receipt download functionality
  - Session conflict handling and JWT token management
  - Real-time error handling and user feedback
  - Mobile-responsive design for cross-device compatibility

### Fund Transfer Frontend Component
- **File**: FundTransfer.html (Single Page Application)
- **Architecture**: Multi-step workflow with client-side state management
- **Purpose**: Complete fund transfer process with professional UX
- **Core Features**:
  - **Step 1 - Transfer Details**: Amount validation and account selection
  - **Step 2 - Payee Management**: Search, select, and add payee functionality
  - **Step 3 - Confirmation**: Transfer review and PIN verification
  - **Step 4 - Processing**: Simulated transaction processing with progress indicators
  - **Step 5 - Receipt**: PDF receipt generation and download
- **State Management**:
  - Client-side validation with real-time feedback
  - Session storage for form data persistence
  - Progressive disclosure with step-by-step navigation
  - Error handling with user-friendly messages
- **Integration Points**:
  - JWT authentication with session validation
  - Account service integration for balance validation
  - PDF service integration for receipt generation
  - Responsive design matching dashboard aesthetics

### API Gateway Layer
- **Service**: login-go-service
- **Technology**: Go with Gin framework v1.9.1
- **Port**: 8000
- **Purpose**: Public API gateway and JWT token generation
- **Responsibilities**:
  - Header validation and security enforcement
  - Request routing and proxying to internal services
  - JWT token creation and management (15-minute expiry)
  - Session conflict resolution and force login handling
  - CORS configuration and cross-origin security

### Authentication Service
- **Service**: login-python-authenticator  
- **Technology**: Python 3.11 with FastAPI framework
- **Port**: 8001
- **Purpose**: User authentication and session management
- **Responsibilities**:
  - Credential verification with bcrypt password hashing
  - Session lifecycle management and conflict detection
  - Login attempt auditing and security logging
  - User role management (retail, corporate, admin)
  - Single active session enforcement

### Account Service
- **Service**: accounts-go-service
- **Technology**: Go with Gin framework and GORM ORM
- **Port**: 8002
- **Purpose**: Account data and transaction management
- **Responsibilities**:
  - Account balance retrieval and management
  - Transaction history and account statements
  - JWT token validation and authorization
  - Protected internal APIs for account operations
  - Real-time balance synchronization

### PDF Receipt Service
- **Service**: pdf-receipt-java-service
- **Technology**: Java 17 with Spring Boot 3.2 and iText 7
- **Port**: 8003
- **Purpose**: Professional PDF receipt generation
- **Responsibilities**:
  - Transaction receipt PDF generation with bank branding
  - Spring Boot actuator health monitoring
  - iText PDF library integration for professional documents
  - CORS-enabled API for frontend integration
  - Dockerized deployment with multi-stage builds

### Database Layer
- **Technology**: PostgreSQL 15 with optimized configuration
- **Port**: 5432
- **Purpose**: Persistent data storage and transaction management
- **Schema**:
  - User authentication and role management
  - Account information with multiple account types
  - Transaction records with audit trails
  - Session management and conflict detection
  - Comprehensive audit logs for security monitoring

## Service Communication

## Service Communication

### Authentication Flow
1. Frontend → Go Gateway (login request with required headers)
2. Go Gateway → Python Auth (credential verification)
3. Python Auth → PostgreSQL (user validation and session check)
4. Go Gateway → JWT token generation with user roles
5. Frontend ← JWT token response with user information

### Data Flow
1. Frontend → Go Gateway (authenticated requests with JWT)
2. Go Gateway → Accounts Service (with validated JWT token)
3. Accounts Service → PostgreSQL (account and transaction data queries)
4. Response chain back to frontend with account information

### PDF Generation Flow
1. Frontend → PDF Service (receipt generation request)
2. PDF Service → iText PDF generation with transaction data
3. PDF Service → Frontend (downloadable PDF response)
4. Frontend → User (PDF download initiated)

### Service Health Monitoring
1. Management Script → All Services (health check requests)
2. Each Service → Database (connectivity validation)
3. Services → Health Status (comprehensive status reporting)
4. Management Script → User (aggregated health information)

### Fund Transfer Processing Flow
1. Frontend → User Input Validation (client-side amount and payee validation)
2. Frontend → Accounts Service (account balance verification via JWT)
3. Frontend → Simulated Processing (realistic 2-3 second processing time)
4. Frontend → PDF Service (receipt generation with transaction data)
5. PDF Service → Frontend (downloadable PDF receipt)
6. Frontend → User (completed transfer confirmation and receipt download)

**Note**: Current implementation uses simulated backend processing. Architecture supports full backend integration with:
- Database transaction processing
- Real account balance updates  
- Audit trail logging
- Fraud detection systems

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

## Deployment Architecture

### Development Environment
- **Frontend**: Custom HTTP server with static file serving
- **Backend Services**: Docker Compose orchestration with service discovery
- **Database**: PostgreSQL container with persistent volume storage
- **Service Discovery**: Docker internal networking with container names
- **Management**: Automated scripts for service lifecycle management

### Container Strategy
- **Multi-stage Builds**: Optimized Docker images for production deployment
- **Health Checks**: Comprehensive service availability monitoring
- **Dependency Management**: Proper service startup order with health checks
- **Volume Persistence**: Database data retention across container restarts
- **Network Isolation**: Docker networks for secure service communication

### Service Management Tools
- **manage-services.sh**: Complete service lifecycle management
- **build-pdf-service.sh**: Specialized PDF service build automation
- **frontend-server.sh**: Frontend server management with logging
- **Health Monitoring**: Automated health checks across all services

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