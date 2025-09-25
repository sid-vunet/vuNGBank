# 📊 VuBank - Centralized APM Configuration

## Overview

VuBank uses **centralized APM configuration** managed through `manage-services.sh` to ensure consistent observability across all services. All APM settings are defined in one place and automatically applied to all backend services and frontend.

## 🎯 Current Configuration

### APM Server Details
- **Server URL**: `http://91.203.133.240:30200`
- **Environment**: `production`
- **Service Version**: `1.0.0`

### Sampling Configuration (100% Maximum Observability)
- **Transaction Sampling**: `1.0` (100%)
- **Span Sampling**: `1.0` (100%)

### Data Capture Configuration (Maximum Capture)
- **Body Capture**: `all` (captures all request/response bodies)
- **Headers Capture**: `true` (captures HTTP headers)
- **Distributed Tracing**: `true` (W3C trace context propagation)

### Performance Settings
- **Stack Trace Limit**: `50` frames
- **Metrics Interval**: `30s`
- **Flush Interval**: `1s` (real-time)
- **Max Queue Size**: `1000` events
- **Transaction Max Spans**: `500`

## 🔧 How to Modify APM Configuration

### Method 1: Edit manage-services.sh (Recommended)
```bash
# Edit the centralized configuration section in manage-services.sh
vim manage-services.sh

# Look for this section:
# ============================================================================
# 📊 CENTRALIZED APM CONFIGURATION (Applied to ALL Services)
# ============================================================================

# Modify any values, then restart services:
./manage-services.sh restart
```

### Method 2: Environment Variables
```bash
# Set environment variables before running
export ELASTIC_APM_SERVER_URL="http://your-apm-server:8200"
export ELASTIC_APM_ENVIRONMENT="staging"
export ELASTIC_APM_TRANSACTION_SAMPLE_RATE="0.1"  # 10% sampling

./manage-services.sh start
```

## 📋 Key Configuration Variables

### Core Settings
| Variable | Default | Description |
|----------|---------|-------------|
| `ELASTIC_APM_SERVER_URL` | `http://91.203.133.240:30200` | APM server endpoint |
| `ELASTIC_APM_ENVIRONMENT` | `production` | Environment name |
| `ELASTIC_APM_SERVICE_VERSION` | `1.0.0` | Version for all services |

### Sampling Settings
| Variable | Default | Description |
|----------|---------|-------------|
| `ELASTIC_APM_TRANSACTION_SAMPLE_RATE` | `1.0` | Transaction sampling (0.0-1.0) |
| `ELASTIC_APM_SPAN_SAMPLE_RATE` | `1.0` | Span sampling (0.0-1.0) |

### Data Capture Settings
| Variable | Default | Description |
|----------|---------|-------------|
| `ELASTIC_APM_CAPTURE_BODY` | `all` | Body capture: `all`, `errors`, `transactions`, `off` |
| `ELASTIC_APM_CAPTURE_HEADERS` | `true` | Capture HTTP headers |
| `ELASTIC_APM_USE_DISTRIBUTED_TRACING` | `true` | Enable distributed tracing |

### Performance Settings
| Variable | Default | Description |
|----------|---------|-------------|
| `ELASTIC_APM_LOG_LEVEL` | `info` | APM agent log level |
| `ELASTIC_APM_STACK_TRACE_LIMIT` | `50` | Stack trace frame limit |
| `ELASTIC_APM_METRICS_INTERVAL` | `30s` | Metrics collection interval |
| `ELASTIC_APM_FLUSH_INTERVAL` | `1s` | Data flush interval |
| `ELASTIC_APM_MAX_QUEUE_SIZE` | `1000` | Event queue size |

## 🏗️ Services Covered

The centralized configuration applies to:

### Backend Services (7 services)
- ✅ **accounts-go-service** (Go)
- ✅ **login-go-service** (Go)  
- ✅ **login-python-authenticator** (Python)
- ✅ **payee-store-dotnet-service** (.NET)
- ✅ **payment-process-java-service** (Java)
- ✅ **pdf-receipt-java-service** (Java)
- ✅ **corebanking-java-service** (Java)

### Frontend
- ✅ **RUM Agent Configuration** (JavaScript)
- ✅ **Distributed Tracing Origins** (Kong Gateway integration)

## 🚀 Usage Commands

### View Current APM Configuration
```bash
./manage-services.sh apm-config
```

### Start Services with Current APM Config
```bash
./manage-services.sh start
```

### Check Service Status (shows APM info)
```bash
./manage-services.sh status
```

### Restart with New Configuration
```bash
# After modifying manage-services.sh
./manage-services.sh restart
```

## 🎯 Benefits of Centralized Configuration

### ✅ Consistency
- All services use identical APM settings
- No configuration drift between services
- Uniform observability across the stack

### ✅ Maintainability  
- Single source of truth for APM settings
- Easy to update all services at once
- Clear documentation in one place

### ✅ Environment Management
- Easy switching between environments (dev/staging/production)
- Consistent sampling rates across all services
- Uniform data capture policies

### ✅ Troubleshooting
- Predictable configuration across all services
- Easy to verify APM settings
- Quick configuration changes without editing multiple files

## 🔍 Verification

After making changes, verify the configuration is applied:

1. **Check centralized config**: `./manage-services.sh apm-config`
2. **View service status**: `./manage-services.sh status`
3. **Check service logs** for APM initialization messages
4. **Verify in APM UI** that all services appear with correct metadata

## 📝 Notes

- Configuration is applied at container startup
- Changes require service restart to take effect
- Environment variables override script defaults
- All services automatically inherit the centralized configuration
- Frontend RUM agent should match backend sampling rates for consistent tracing

---
**VuBank APM Configuration - Centralized Management for Maximum Observability** 📊