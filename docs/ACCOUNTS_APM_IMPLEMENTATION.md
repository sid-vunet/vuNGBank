# Accounts Service APM Implementation

## Overview
This document describes the Elastic APM implementation for the VuBank Accounts Go Service, which provides comprehensive observability and distributed tracing capabilities.

## APM Configuration

### Environment Variables
The accounts service is configured with the following APM environment variables:

```bash
ELASTIC_APM_SERVICE_NAME=vubank-accounts-service
ELASTIC_APM_SERVER_URL=http://91.203.133.240:30200
ELASTIC_APM_ENVIRONMENT=production
ELASTIC_APM_SERVICE_VERSION=1.0.0
```

### Dependencies Added
- `go.elastic.co/apm/v2` - Core APM library
- `go.elastic.co/apm/module/apmgin/v2` - Gin middleware integration
- `go.elastic.co/apm/module/apmsql/v2` - Database instrumentation
- `go.elastic.co/apm/module/apmsql/v2/pq` - PostgreSQL driver integration

## Implementation Details

### 1. APM Middleware Integration
The Gin router is instrumented with APM middleware to capture HTTP transactions:

```go
r.Use(apmgin.Middleware(r))
```

### 2. Database Instrumentation
PostgreSQL database connections are instrumented using APM SQL middleware:

```go
db, err := apmsql.Open("postgres", connStr)
```

### 3. Custom Spans and Labels

#### getUserAccounts Function
- **Span Name**: `database_accounts_lookup`
- **Span Type**: `db.postgresql`
- **Labels**:
  - `user_id`: User identifier
  - `operation`: "get_accounts"
  - `query_result`: "success" | "error"
  - `accounts_count`: Number of accounts retrieved

#### getRecentTransactions Function
- **Span Name**: `database_transactions_lookup`
- **Span Type**: `db.postgresql`
- **Labels**:
  - `user_id`: User identifier
  - `operation`: "get_recent_transactions"
  - `query_result`: "success" | "error"
  - `transactions_count`: Number of transactions retrieved

#### accountsHandler Function
- **Business Logic Span**: `accounts_business_logic`
- **Transaction Labels**:
  - `user_id`: Authenticated user ID
  - `endpoint`: "accounts"
  - `user_roles`: Comma-separated user roles
  - `response_accounts_count`: Number of accounts in response
  - `response_transactions_count`: Number of transactions in response

#### healthHandler Function
- **Span Name**: `health_check`
- **Span Type**: `app`
- **Labels**:
  - `db_healthy`: Database health status
  - `health_result`: "healthy" | "unhealthy"

## Distributed Tracing

### Trace Propagation
The service automatically propagates trace context from incoming requests using the `traceparent` and `tracestate` headers, enabling end-to-end distributed tracing across the VuBank platform.

### Integration Points
1. **Frontend RUM** → Login Service → **Accounts Service**
2. **Login Service** → **Accounts Service** (JWT validation flow)
3. **Accounts Service** → PostgreSQL Database

## Business Intelligence Labels

### Authentication Context
- `user_id`: Tracks account operations per user
- `user_roles`: Business role segmentation (retail, corporate)
- `endpoint`: API endpoint identification

### Performance Metrics
- `accounts_count`: Number of accounts per user
- `transactions_count`: Transaction volume metrics
- `query_result`: Database operation success/failure rates

### Health Monitoring
- `db_healthy`: Database connectivity status
- `service`: Service identification

## Error Tracking

### Automatic Error Capture
- Database connection errors
- Query execution failures
- Data scanning errors
- Business logic exceptions

### Error Context
All errors include:
- User context (user_id, roles)
- Operation context (span names, types)
- Database query context
- Request trace correlation

## Monitoring Benefits

### 1. Performance Monitoring
- Database query performance
- Account retrieval latency
- Transaction lookup performance
- Health check response times

### 2. Business Intelligence
- User account access patterns
- Transaction volume analysis
- Role-based usage analytics
- Service dependency mapping

### 3. Error Analysis
- Database connectivity issues
- Query failure analysis
- Authentication failure tracking
- Service availability monitoring

### 4. Distributed Tracing
- End-to-end request flow visualization
- Service dependency mapping
- Performance bottleneck identification
- Cross-service error correlation

## APM Dashboard Metrics

### Key Metrics to Monitor
1. **Response Times**: Account retrieval and transaction lookup latency
2. **Error Rates**: Database and business logic error frequencies
3. **Throughput**: Request volume and user activity patterns
4. **Database Performance**: Query execution times and connection health
5. **User Segmentation**: Usage patterns by user roles

### Service Dependencies
- PostgreSQL Database (vubank-postgres:5432)
- Login Service (JWT token validation)
- Frontend Application (CORS and user requests)

## Deployment

### Docker Configuration
The service is containerized with APM environment variables configured in docker-compose.yml:

```yaml
accounts-go-service:
  environment:
    ELASTIC_APM_SERVICE_NAME: vubank-accounts-service
    ELASTIC_APM_SERVER_URL: http://91.203.133.240:30200
    ELASTIC_APM_ENVIRONMENT: production
    ELASTIC_APM_SERVICE_VERSION: 1.0.0
```

### Service Health
Health check endpoint (`/health`) includes APM instrumentation to monitor:
- Service availability
- Database connectivity
- APM trace correlation

## Testing APM Integration

### Test Endpoints
1. **Health Check**: `GET /health`
   - Tests basic APM instrumentation
   - Database connectivity monitoring

2. **Accounts Retrieval**: `GET /internal/accounts` (requires JWT)
   - Tests complete distributed tracing
   - Database operation instrumentation
   - Business logic span tracking

### Trace Validation
Verify APM traces in the Elastic APM dashboard:
1. Service appears as "vubank-accounts-service"
2. Database queries are instrumented
3. Custom spans include business context
4. Error tracking captures failures
5. Distributed traces correlate with login service

## Integration Status
✅ APM Client Initialization
✅ Gin Middleware Integration
✅ Database Instrumentation
✅ Custom Spans and Labels
✅ Error Tracking
✅ Distributed Tracing Support
✅ Docker Configuration
✅ Health Check Instrumentation
✅ Business Intelligence Labels