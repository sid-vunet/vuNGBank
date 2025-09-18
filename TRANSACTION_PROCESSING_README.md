# VuBank Transaction Processing System

This document describes the new dynamic transaction processing system that replaces the static fund transfer functionality with real, stateful transaction processing.

## Architecture Overview

The transaction processing system consists of two main services:

1. **Payment Process Java Service** (Port 8004) - External API for payments, validates PACS XML, manages transaction state
2. **CoreBanking Java Service** (Port 8005) - Internal core banking service that processes payments and persists data

## Key Features

### Dynamic Status Updates
- **Initiated** → Transaction received and validated
- **In Progress** → CoreBanking processing (1.5s simulation)
- **Success/Failed** → Final status with cbsId or failure reason

### Real Transaction Flow
1. Frontend sends PACS XML to payment service
2. Service validates headers, XML, and balance
3. Creates txnRef and stores state in Redis
4. Calls CoreBanking service asynchronously
5. Frontend polls status every 1 second
6. CoreBanking simulates processing and returns result
7. Final status displayed to user

### PACS XML Format
```xml
<?xml version="1.0" encoding="UTF-8"?>
<PaymentInstruction>
    <PayeeName>John Doe</PayeeName>
    <IFSCCode>HDFC0000123</IFSCCode>
    <PaymentType>NEFT</PaymentType>
    <DateTime>2025-01-18T10:30:00Z</DateTime>
    <CustomerName>Jane Smith</CustomerName>
    <FromAccountNo>1001234567</FromAccountNo>
    <ToAccountNo>2001234567</ToAccountNo>
    <BranchName>Main Branch</BranchName>
    <Amount>1000.00</Amount>
    <Comments>Monthly rent payment</Comments>
</PaymentInstruction>
```

### API Endpoints

#### Payment Process Service (8004)
- `POST /payments/transfer` - Initiate payment with PACS XML
- `GET /payments/status/{txnRef}` - Poll transaction status

#### CoreBanking Service (8005)
- `POST /core/payments` - Internal payment processing
- `GET /core/payments/{cbsId}` - Get payment by CBS ID (optional)

### Required Headers
```
X-Api-Client: web-portal
X-Request-Id: <uuid>
Content-Type: application/xml
X-Signature: <signature>
Authorization: Bearer <token>
```

## State Management

### Redis Keys
- `txn:{txnRef}` - Transaction state with all details
- `bal:{accountNo}` - Cached account balance
- `lock:txn:{idempotencyKey}` - Idempotency locks

### PostgreSQL Tables
- `core_payments` - All payment transactions with cbsId mapping
- `core_accounts` - Account balances for reporting

## Configuration

### Payment Process Service
```properties
server.port=8004
spring.redis.host=redis
corebanking.service.url=http://corebanking-java-service:8005
transaction.ttl.hours=48
validation.ifsc.pattern=^[A-Z]{4}0[A-Z0-9]{6}$
```

### CoreBanking Service
```properties
server.port=8005
spring.datasource.url=jdbc:postgresql://postgres:5432/vubank_db
processing.simulation.delay.ms=1500
security.shared-secret=vubank-core-secret-2024
```

## Frontend Changes

### Status Polling
- Polls `/payments/status/{txnRef}` every 1 second
- Displays real-time status updates
- Shows transaction reference immediately
- Handles timeout scenarios

### Enhanced UI
- Loading overlay with status indicators
- Dynamic status messages
- Error handling for validation failures
- Support for insufficient balance scenarios

## Error Scenarios

### Validation Errors (400)
- Invalid XML format
- Missing required fields
- Invalid IFSC code
- Amount <= 0

### Business Errors (402/409)
- Insufficient balance
- Duplicate transaction
- Account validation failures

### System Errors (500)
- CoreBanking service timeout
- Redis connection issues
- Database errors

## Observability

### Elastic APM Integration
- All services instrumented with APM
- Distributed tracing across services
- Transaction correlation with trace IDs
- Performance monitoring

### Logging
- Structured logs with correlation IDs
- Request/response tracing
- Error reporting with context
- Transaction lifecycle logging

## Security

### Authentication
- JWT token validation
- Service-to-service shared secrets
- Request signature validation (placeholder)

### Data Protection
- PII masking in logs
- Secure inter-service communication
- Input validation and sanitization
- SQL injection protection

## Deployment

### Docker Services
```yaml
# Redis for state management
redis:
  image: redis:7-alpine
  
# Payment processing service
payment-process-java-service:
  build: ./backend/services/payment-process-java-service
  ports: ["8004:8004"]
  
# CoreBanking service
corebanking-java-service:
  build: ./backend/services/corebanking-java-service
  ports: ["8005:8005"]
```

### Health Checks
- Service health endpoints
- Database connectivity checks
- Redis connectivity validation
- Dependency health monitoring

## Testing

### Manual Testing
1. Login to frontend
2. Navigate to Fund Transfer
3. Fill transfer details and PIN (123456)
4. Observe status progression:
   - Initiated (immediate)
   - Processing (after validation)
   - Success/Failed (after ~1.5s)

### API Testing
```bash
# Test payment initiation
curl -X POST http://localhost:8004/payments/transfer \
  -H "Content-Type: application/xml" \
  -H "X-Api-Client: web-portal" \
  -H "X-Request-Id: $(uuidgen)" \
  -d "<PaymentInstruction>...</PaymentInstruction>"

# Test status polling
curl http://localhost:8004/payments/status/{txnRef}
```

## Troubleshooting

### Common Issues
1. **Service startup failures** - Check Docker logs and port conflicts
2. **Redis connection errors** - Verify Redis container is running
3. **Database connection issues** - Check PostgreSQL container health
4. **CORS errors** - Ensure frontend origins are configured
5. **Authentication failures** - Verify JWT token validity

### Debug Commands
```bash
# Check service logs
docker logs payment-process-java-service
docker logs corebanking-java-service

# Check Redis state
docker exec -it vubank-redis redis-cli
KEYS txn:*

# Check database
docker exec -it vubank-postgres psql -U vubank_user -d vubank_db
SELECT * FROM core_payments ORDER BY created_at DESC LIMIT 10;
```

## Future Enhancements

1. **Real CoreBanking Integration** - Replace simulation with actual core banking calls
2. **Enhanced Validation** - Implement proper PACS XML schema validation
3. **Real-time Notifications** - WebSocket support for instant status updates
4. **Advanced Security** - Implement proper digital signatures
5. **Audit Trail** - Enhanced transaction audit and compliance reporting
6. **Multi-currency Support** - Support for international transfers
7. **Batch Processing** - Support for bulk payment processing
8. **Reconciliation** - Automated reconciliation with external systems