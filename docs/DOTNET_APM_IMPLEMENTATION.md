# Elastic APM Integration for .NET Payee Service

## Overview
This document describes the Elastic APM configuration for the VuBank Payee Store .NET service.

## Configuration Details

### APM Server Configuration
- **APM Server URL**: `http://91.203.133.240:30200`
- **Service Name**: `vubank-payee-service`
- **Environment**: `production`
- **Service Version**: `1.0.0`

### Implementation

#### 1. NuGet Package
Added the following package to `PayeeService.csproj`:
```xml
<PackageReference Include="Elastic.Apm.NetCoreAll" Version="1.28.0" />
```

#### 2. Service Registration
Added APM service registration in `Program.cs`:
```csharp
builder.Services.AddAllElasticApm();
```

#### 3. Environment Variables (docker-compose.yml)
```yaml
environment:
  ELASTIC_APM_SERVER_URLS: http://91.203.133.240:30200
  ELASTIC_APM_SERVICE_NAME: vubank-payee-service
  ELASTIC_APM_ENVIRONMENT: production
  ELASTIC_APM_SERVICE_VERSION: 1.0.0
  ELASTIC_APM_APPLICATION_PACKAGES: PayeeService
```

#### 4. APM Settings Files
- `appsettings.json`: Development APM configuration
- `appsettings.Production.json`: Production-optimized APM configuration

#### 5. Manual Instrumentation
Added custom spans and labels in `PayeesController.cs`:
- Transaction labels for user identification
- Database operation spans
- Exception capture
- Performance metrics

### Health Check Integration
The `/health` endpoint now includes APM status:
```json
{
  "status": "healthy",
  "service": "Payee Store Service",
  "version": "1.0.0",
  "timestamp": "2025-09-17T21:35:22.742058Z",
  "apm": {
    "enabled": true,
    "serverUrl": "http://91.203.133.240:30200",
    "serviceName": "vubank-payee-service",
    "environment": "production"
  }
}
```

### APM Features Enabled

#### Automatic Instrumentation
- HTTP requests/responses
- Database queries (Entity Framework Core)
- Exceptions and errors
- Performance metrics

#### Custom Instrumentation
- Business logic spans
- User context tracking
- Custom labels and metadata
- Error categorization

#### Configuration
- Transaction sampling rate: 50% (production)
- Capture headers: disabled (production)
- Capture body: errors only (production)
- Stack trace limit: 30 frames

### Verification
1. **Service Status**: ✅ APM agent is active
2. **Server Connection**: ✅ Connected to APM Server 8.17.2
3. **OpenTelemetry Bridge**: ✅ Active for Activity-based tracing
4. **Metrics Collection**: ✅ 30-second intervals
5. **Environment Variables**: ✅ All APM settings loaded correctly

### Monitoring Capabilities
With APM enabled, you can monitor:
- Request/response times for all API endpoints
- Database query performance
- Error rates and exception details
- User activity tracking
- Service dependencies and external calls
- Custom business metrics and KPIs

The service is now fully instrumented and will send APM data to the Elastic stack for observability and performance monitoring.