# Kong API Gateway Implementation for VuNG Bank

## Overview

This document provides comprehensive instructions for deploying Kong API Gateway as an enterprise-level API management solution for the VuNG Bank microservices system. Kong consolidates all services behind a single entry point (port 8086) with comprehensive APM monitoring, security features, and distributed tracing.

## Architecture

```
                                    ┌─────────────────┐
                                    │   Kong Gateway  │
                                    │   Port: 8086    │
                                    └─────────┬───────┘
                                              │
                ┌─────────────────────────────┼─────────────────────────────┐
                │                             │                             │
                ▼                             ▼                             ▼
        ┌───────────────┐           ┌─────────────────┐           ┌─────────────────┐
        │   Frontend    │           │  Backend APIs   │           │  Database &     │
        │ (HTML/JS/CSS) │           │   (7 Services)  │           │  External APIs  │
        │   Port: 80    │           │  Ports: 8000-   │           │   Port: 5432    │
        │   (Internal)  │           │  8005, 5004     │           │   (Internal)    │
        └───────────────┘           │   (Internal)    │           └─────────────────┘
                                    └─────────────────┘                     
```

## Key Features

### ✅ Enterprise API Management
- **Single Entry Point**: All traffic through port 8086
- **Service Discovery**: Automatic routing to backend services
- **Load Balancing**: Built-in load balancing with health checks
- **API Versioning**: Version management and backward compatibility

### ✅ Comprehensive Security
- **JWT Authentication**: Token-based authentication for protected endpoints
- **API Key Management**: Service-to-service authentication
- **Rate Limiting**: Advanced rate limiting with multiple policies
- **CORS Protection**: Dynamic CORS configuration
- **Security Headers**: Comprehensive security header injection
- **IP Restrictions**: Admin endpoint protection

### ✅ Advanced APM & Monitoring
- **Elastic APM Integration**: Custom plugin for comprehensive monitoring
- **Distributed Tracing**: W3C Trace Context propagation
- **Request/Response Logging**: Full body and header capture
- **Correlation ID Tracking**: End-to-end correlation across services
- **Prometheus Metrics**: Performance metrics collection
- **Health Monitoring**: Service health check aggregation

## Quick Start

### 1. Start Kong Gateway with All Services

```bash
# Start Kong with all VuNG Bank services
./manage-services.sh start

# This will:
# 1. Start Kong database and run migrations
# 2. Build and start Kong Gateway with custom APM plugin
# 3. Start all backend services (internal ports only)
# 4. Start HTML frontend (internal port only)
# 5. Wait for all services to be ready
```

### 2. Verify Deployment

```bash
# Check all services are running
./manage-services.sh status

# Run comprehensive tests
./test_kong_gateway.sh

# Test APM and distributed tracing
./test_kong_apm_tracing.sh
```

### 3. Access Your Application

- **Main Application**: http://localhost:8086
- **Login Page**: http://localhost:8086/login.html
- **Dashboard**: http://localhost:8086/dashboard.html
- **Fund Transfer**: http://localhost:8086/FundTransfer.html
- **Kong Admin API**: http://localhost:8001
- **Kong Admin GUI**: http://localhost:8002

## API Endpoints

All APIs are now accessed through Kong Gateway on port 8086:

### Authentication APIs
```
POST http://localhost:8086/api/login
POST http://localhost:8086/api/logout
GET  http://localhost:8086/api/session
```

### Account APIs
```
GET  http://localhost:8086/accounts
GET  http://localhost:8086/accounts/balance
GET  http://localhost:8086/accounts/statements
```

### Payment APIs
```
POST http://localhost:8086/payments/initiate
GET  http://localhost:8086/payments/status
GET  http://localhost:8086/payments/history
```

### Utility APIs
```
POST http://localhost:8086/api/pdf/generate
GET  http://localhost:8086/api/pdf/download
GET  http://localhost:8086/api/payees
GET  http://localhost:8086/core/health
```

## Configuration Files

### Key Configuration Files

```
kong/
├── Dockerfile                    # Kong with custom APM plugin
├── kong.conf                    # Kong configuration
├── kong-declarative.yml         # Services, routes, and plugins
├── plugins/
│   └── elastic-apm/             # Custom Elastic APM plugin
│       ├── handler.lua          # Plugin implementation
│       ├── schema.lua           # Plugin schema
│       └── *.rockspec           # Plugin metadata
└── config/
    └── security-plugins.yml     # Advanced security configuration
```

### Docker Compose Changes

Kong services added to `docker-compose.yml`:

```yaml
# Kong PostgreSQL Database
kong-postgres:
  image: postgres:15
  # ... configuration

# Kong Database Migrations  
kong-migrations:
  image: kong:3.8.0
  command: kong migrations bootstrap
  # ... configuration

# Kong API Gateway
vubank-kong-gateway:
  build: ./kong
  ports:
    - "8086:8086"  # Main API Gateway
    - "8001:8001"  # Admin API
    - "8002:8002"  # Admin GUI
  # ... configuration with APM
```

All backend services now have external ports commented out - traffic only flows through Kong.

## APM Integration

### Elastic APM Configuration

Kong gateway includes a custom Elastic APM plugin that:

- ✅ **Preserves Distributed Tracing**: Maintains trace context from frontend through backend services
- ✅ **Captures Request/Response Data**: Full body and header capture with size limits
- ✅ **Correlation ID Propagation**: Ensures end-to-end correlation tracking
- ✅ **Performance Monitoring**: Detailed timing and performance metrics
- ✅ **Error Tracking**: Comprehensive error and exception tracking

### APM Configuration Variables

```bash
# Environment variables in docker-compose.yml
ELASTIC_APM_SERVER_URL=http://91.203.133.240:30200
ELASTIC_APM_SERVICE_NAME=vubank-kong-gateway  
ELASTIC_APM_ENVIRONMENT=production
ELASTIC_APM_SERVICE_VERSION=1.0.0
```

### Trace Context Headers

Kong automatically handles and propagates these headers:

- `traceparent`: W3C Trace Context specification
- `tracestate`: Trace state information
- `X-Correlation-ID`: VuNG Bank correlation tracking
- `X-Request-ID`: Unique request identification

## Security Configuration

### JWT Authentication

Protected endpoints require JWT tokens:

```bash
# Get JWT token from login
curl -X POST http://localhost:8086/api/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@vubank.com","password":"password"}'

# Use JWT token for protected endpoints
curl -H "Authorization: Bearer <jwt-token>" \
  http://localhost:8086/accounts/balance
```

### Rate Limiting Policies

- **Frontend**: 100 requests/minute
- **Standard APIs**: 50 requests/minute, 500/hour
- **Heavy Operations**: 10 requests/minute, 100/hour (payments, PDF generation)

### Security Headers

All responses include comprehensive security headers:

```
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
Strict-Transport-Security: max-age=31536000; includeSubDomains
Content-Security-Policy: [comprehensive policy]
```

## Monitoring & Observability

### Health Checks

```bash
# Check Kong Gateway health
curl http://localhost:8086/
curl http://localhost:8001/

# Check individual service health through Kong
curl http://localhost:8086/api/health      # Login service
curl http://localhost:8086/health          # Auth service  
curl http://localhost:8086/accounts        # Accounts service
curl http://localhost:8086/payments/health # Payment service
```

### Prometheus Metrics

Kong exposes Prometheus metrics at:
```
GET http://localhost:8086/metrics
```

Metrics include:
- Request count and rates
- Response times and latencies  
- Error rates by service
- Upstream health status
- Kong-specific metrics

### Log Analysis

Kong logs include:
- Request/response details with correlation IDs
- APM trace information
- Performance timing data
- Error details with stack traces

Access logs:
```bash
# Kong gateway logs
docker logs vubank-kong-gateway

# Backend service logs (with trace correlation)
docker logs login-go-service
docker logs payment-process-java-service
# ... other services
```

## Testing

### Comprehensive Test Suite

```bash
# Basic functionality and routing tests
./test_kong_gateway.sh

# APM and distributed tracing validation
./test_kong_apm_tracing.sh
```

### Test Coverage

The test suites validate:
- ✅ Kong Gateway health and availability
- ✅ Frontend page routing
- ✅ API endpoint routing with proper responses
- ✅ Authentication flow with JWT tokens
- ✅ Protected endpoint access control
- ✅ Security headers and CORS
- ✅ Rate limiting functionality
- ✅ Distributed tracing continuity
- ✅ APM data collection and correlation
- ✅ Error scenario tracing
- ✅ Concurrent transaction handling

## Troubleshooting

### Common Issues

1. **Kong Gateway Not Starting**
   ```bash
   # Check Kong database is ready
   docker logs kong-postgres
   docker logs kong-migrations
   
   # Verify Kong configuration
   docker logs vubank-kong-gateway
   ```

2. **Backend Services Not Accessible**
   ```bash
   # Verify services are running internally
   docker exec vubank-kong-gateway curl http://login-go-service:8000/api/health
   
   # Check Kong service configuration
   curl http://localhost:8001/services
   curl http://localhost:8001/routes
   ```

3. **APM Data Not Appearing**
   ```bash
   # Check APM server connectivity
   curl http://91.203.133.240:30200/healthcheck
   
   # Verify APM plugin is active
   curl http://localhost:8001/plugins
   
   # Check correlation IDs in logs
   docker logs vubank-kong-gateway | grep -i correlation
   ```

4. **Authentication Issues**
   ```bash
   # Test login endpoint directly
   curl -X POST http://localhost:8086/api/login \
     -H "Content-Type: application/json" \
     -d '{"email":"testuser@vubank.com","password":"Test@123456"}'
   
   # Check JWT configuration
   curl http://localhost:8001/plugins | jq '.data[] | select(.name=="jwt")'
   ```

### Debug Mode

Enable debug logging:
```bash
# Set Kong log level to debug
export KONG_LOG_LEVEL=debug

# Restart Kong with debug logging
docker compose --profile kong restart vubank-kong-gateway
```

### Service Status Commands

```bash
# Quick status check
./manage-services.sh status

# Detailed health check
./manage-services.sh health

# View logs
./manage-services.sh logs

# Restart services
./manage-services.sh restart
```

## Production Considerations

### Performance Tuning

1. **Kong Configuration**
   ```
   # In kong.conf
   worker_processes = auto
   worker_connections = 4096
   upstream_keepalive_pool_size = 60
   upstream_keepalive_max_requests = 100
   ```

2. **Database Optimization**
   - Use dedicated PostgreSQL instance for Kong
   - Configure connection pooling
   - Regular database maintenance

3. **APM Sampling**
   - Adjust `transaction_sample_rate` based on traffic volume
   - Configure APM data retention policies
   - Set up APM alerting thresholds

### Security Hardening

1. **Network Security**
   - Use HTTPS in production with proper certificates
   - Configure firewall rules to block direct backend access
   - Set up VPN/private networks for admin access

2. **Authentication**
   - Use strong JWT secrets
   - Implement JWT token rotation
   - Configure session timeouts

3. **Monitoring**
   - Set up alerting for failed health checks
   - Monitor rate limiting violations
   - Track authentication failures

### High Availability

1. **Kong Clustering**
   ```yaml
   # Multiple Kong nodes with shared database
   kong-node-1:
     # ... configuration
   kong-node-2:
     # ... configuration
   ```

2. **Load Balancing**
   - Use external load balancer for Kong instances
   - Configure health check endpoints
   - Implement circuit breakers

3. **Database HA**
   - PostgreSQL clustering/replication
   - Automated failover
   - Regular backups

## Success Metrics

After successful deployment, you should see:

✅ **Single Entry Point**: All traffic flowing through http://localhost:8086  
✅ **API Gateway**: Kong routing requests to appropriate backend services  
✅ **Security**: JWT authentication, rate limiting, and security headers active  
✅ **APM Integration**: Traces visible in Elastic APM with correlation IDs  
✅ **Distributed Tracing**: End-to-end trace propagation across all services  
✅ **Performance Monitoring**: Kong metrics and service health tracking  
✅ **Error Tracking**: Comprehensive error capture and correlation  

## Support

For issues and questions:

1. **Check Test Results**: Run test suites to identify specific issues
2. **Review Logs**: Use correlation IDs to trace requests across services  
3. **Kong Admin API**: Use admin API to inspect configuration
4. **APM Dashboard**: Check Elastic APM for performance and error data

## Next Steps

1. **Production Setup**: Configure HTTPS, proper certificates, and production APM
2. **Monitoring**: Set up dashboards and alerting based on Kong metrics
3. **Security**: Implement additional security policies as needed
4. **Performance**: Tune Kong and backend services based on production load
5. **Documentation**: Update API documentation with new Kong endpoints

---

**VuNG Bank Kong Gateway Implementation Complete** ✅

Your enterprise-level API gateway is now ready with comprehensive APM monitoring, security features, and distributed tracing!