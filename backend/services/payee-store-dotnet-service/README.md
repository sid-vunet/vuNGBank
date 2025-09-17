# VuBank Payee Store Service (.NET)

A comprehensive payee management microservice built with .NET 8.0 and Entity Framework Core, providing secure payee storage and IFSC validation capabilities for the VuBank banking platform.

## Features

- **Secure Payee Management**: Add, retrieve, and delete payees with JWT authentication
- **IFSC Validation**: Real-time bank details validation using Razorpay IFSC API
- **Database Integration**: PostgreSQL with Entity Framework Core
- **RESTful API**: Clean, well-documented API endpoints
- **Containerized**: Docker support with health checks
- **Comprehensive Logging**: Structured logging with Serilog
- **API Documentation**: Swagger/OpenAPI integration

## API Endpoints

### Authentication Required
All endpoints require a valid JWT token in the Authorization header:
```
Authorization: Bearer <jwt_token>
```

### Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/payees` | Get all payees for authenticated user |
| GET | `/api/payees/{id}` | Get specific payee by ID |
| POST | `/api/payees` | Add new payee with IFSC validation |
| DELETE | `/api/payees/{id}` | Delete payee by ID |
| POST | `/api/payees/exists` | Check if payee exists |
| GET | `/api/health` | Service health check |

## Data Models

### Payee Model
```json
{
  "id": 1,
  "beneficiaryName": "John Doe",
  "accountNumber": "1234567890123456",
  "ifscCode": "SBIN0000001",
  "bankName": "State Bank of India",
  "branchName": "Main Branch",
  "accountType": "Savings",
  "createdAt": "2024-01-15T10:30:00Z"
}
```

### Add Payee Request
```json
{
  "beneficiaryName": "John Doe",
  "accountNumber": "1234567890123456", 
  "ifscCode": "SBIN0000001",
  "accountType": "Savings"
}
```

## Setup and Running

### Prerequisites
- .NET 8.0 SDK
- PostgreSQL database
- Docker (optional)

### Local Development
1. **Clone and navigate:**
   ```bash
   cd backend/services/payee-store-dotnet-service
   ```

2. **Install dependencies:**
   ```bash
   dotnet restore
   ```

3. **Configure database:**
   Update `appsettings.json` or set environment variable:
   ```json
   {
     "ConnectionStrings": {
       "DefaultConnection": "Host=localhost;Port=5432;Database=vubank_db;Username=vubank_user;Password=vubank_pass;"
     }
   }
   ```

4. **Run the service:**
   ```bash
   dotnet run
   ```

5. **Access API:**
   - Service: http://localhost:5004
   - Swagger UI: http://localhost:5004/swagger

### Docker Deployment
1. **Build image:**
   ```bash
   docker build -t vubank-payee-service .
   ```

2. **Run container:**
   ```bash
   docker run -p 5004:5004 \
     -e ConnectionStrings__DefaultConnection="Host=postgres;Port=5432;Database=vubank_db;Username=vubank_user;Password=vubank_pass;" \
     -e JWT_SECRET="your-jwt-secret" \
     vubank-payee-service
   ```

### Docker Compose
The service is included in the main `docker-compose.yml`:
```bash
cd /path/to/vubank
docker-compose up payee-store-dotnet-service
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ConnectionStrings__DefaultConnection` | PostgreSQL connection string | localhost connection |
| `JWT_SECRET` | JWT signing key | development key |
| `ASPNETCORE_ENVIRONMENT` | Environment (Development/Production) | Development |
| `ASPNETCORE_URLS` | Service URLs | http://+:5004 |

## Database Schema

### Payees Table
```sql
CREATE TABLE Payees (
    Id SERIAL PRIMARY KEY,
    UserId VARCHAR(50) NOT NULL,
    BeneficiaryName VARCHAR(100) NOT NULL,
    AccountNumber VARCHAR(50) NOT NULL,
    IfscCode VARCHAR(11) NOT NULL,
    BankName VARCHAR(100) NOT NULL,
    BranchName VARCHAR(100) NOT NULL,
    AccountType VARCHAR(20) NOT NULL DEFAULT 'Savings',
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT UK_Payees_UserAccount UNIQUE (UserId, AccountNumber, IfscCode)
);

CREATE INDEX IX_Payees_UserId ON Payees (UserId);
CREATE INDEX IX_Payees_IfscCode ON Payees (IfscCode);
```

## IFSC Validation

The service integrates with Razorpay's IFSC API to validate bank codes and fetch bank details:

- **API**: https://ifsc.razorpay.com/{ifsc_code}
- **Validation**: Real-time IFSC code format and bank details verification
- **Response**: Bank name, branch name, city, and state information
- **Error Handling**: Graceful fallback for API unavailability

## Security Features

- **JWT Authentication**: Secure endpoint access
- **User Isolation**: Users can only access their own payees
- **Input Validation**: Comprehensive request validation
- **SQL Injection Protection**: Entity Framework parameterized queries
- **CORS Configuration**: Restricted to VuBank frontend origins

## Testing

### Health Check
```bash
curl http://localhost:5004/api/health
```

### Add Payee (with authentication)
```bash
curl -X POST http://localhost:5004/api/payees \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "beneficiaryName": "Test User",
    "accountNumber": "1234567890123456",
    "ifscCode": "SBIN0000001",
    "accountType": "Savings"
  }'
```

## Integration

### With VuBank Frontend
The service integrates with the VuBank frontend fund transfer system:

1. **Authentication**: Uses JWT tokens from login service
2. **API Calls**: Frontend makes AJAX calls to payee endpoints
3. **CORS**: Configured to allow requests from frontend domains
4. **Error Handling**: Returns structured error responses

### With Other Services
- **Login Service**: Validates JWT tokens
- **Database**: Shares PostgreSQL with other services
- **Monitoring**: Health checks for container orchestration

## Architecture

```
Frontend (React/HTML) 
    ↓ (JWT Token)
PayeesController
    ↓
PayeeService (Business Logic)
    ↓
PayeeDbContext (Entity Framework)
    ↓
PostgreSQL Database

External: IfscService → Razorpay IFSC API
```

## Error Handling

- **400 Bad Request**: Invalid input data or IFSC code
- **401 Unauthorized**: Missing or invalid JWT token
- **404 Not Found**: Payee not found for user
- **409 Conflict**: Duplicate payee (same account + IFSC)
- **500 Internal Server Error**: Database or service errors

## Logging

The service provides comprehensive logging:
- **Request/Response logging**
- **Database operations**
- **IFSC validation attempts**
- **Error tracking with stack traces**
- **Performance metrics**

## Contributing

1. Follow .NET coding standards
2. Add unit tests for new features
3. Update API documentation
4. Test IFSC validation scenarios
5. Verify JWT authentication flows

## Version History

- **v1.0.0**: Initial release with core payee management
- IFSC validation integration
- Docker containerization
- PostgreSQL integration
- JWT authentication