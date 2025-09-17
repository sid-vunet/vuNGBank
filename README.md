# VuBank NextGen Banking Platform

A full-stack banking simulation platform that mimics VuBank's Straight2Bank interface and operations using synthetic data.

# VuBank NextGen Banking Platform

A comprehensive banking simulation platform that replicates VuBank's Straight2Bank interface using modern web technologies and microservices architecture with synthetic data.

## Project Structure

```
vuNGBank/
├── frontend/          # HTML/CSS/JS banking interface
├── backend/           # Microservices architecture
│   ├── services/      # Individual service implementations
│   │   ├── login-go-service/           # Go API Gateway (8000)
│   │   ├── login-python-authenticator/ # Python Auth Service (8001)
│   │   ├── accounts-go-service/        # Go Accounts Service (8002)
│   │   └── pdf-receipt-java-service/   # Java PDF Service (8003)
│   ├── db/           # Database initialization scripts
│   └── index.js      # Node.js coordination layer
├── docs/             # Comprehensive project documentation
├── .github/          # GitHub configuration
├── docker-compose.yml         # Service orchestration
├── manage-services.sh         # Service management script
└── build-pdf-service.sh      # PDF service build utility
```

## 📚 Documentation

Comprehensive documentation is available in the [`docs/`](./docs/) folder:

- **[🏗️ Architecture](./docs/ARCHITECTURE.md)** - System architecture, components, and high-level design
- **[🔧 API Reference](./docs/API.md)** - Complete REST API documentation with examples
- **[🗄️ Database Schema](./docs/DATABASE.md)** - Database design, tables, indexes, and queries
- **[⚙️ Technical Decisions](./docs/DECISIONS.md)** - Architectural decisions and trade-offs
- **[📋 Coding Style Guide](./docs/STYLE.md)** - Coding standards and best practices
- **[🔄 Data Flows](./docs/FLOW.md)** - User journeys and system data flows

## Features

- **Authentication System**: Multi-layer authentication with JWT tokens and session management
- **Dashboard Interface**: Modern banking dashboard matching VuBank's design principles
- **Account Management**: Multiple account types with real-time balance tracking
- **Fund Transfer System**: Complete multi-step transfer process with payee management
- **PDF Receipt Generation**: Professional PDF receipts using Java Spring Boot service
- **Transaction History**: Synthetic transaction data with realistic banking patterns
- **Microservices Architecture**: Modular backend services for scalability and maintainability
- **Responsive Design**: Mobile-friendly interface with cross-device compatibility
- **Synthetic Data**: Comprehensive realistic banking data for testing and demonstration
- **Session Management**: Single active session with conflict resolution
- **Service Management**: Automated service orchestration and health monitoring

## Technology Stack

### Frontend
- **HTML5** with semantic markup and accessibility features
- **Vanilla JavaScript (ES6+)** with modern API integration
- **CSS3** with custom styling matching VuBank branding
- **Responsive Design** principles for cross-device compatibility
- **AJAX/Fetch API** for seamless backend communication
- **JWT Token Management** for secure authentication

### Backend Microservices
- **Go Services**: High-performance API gateway and accounts management
- **Python Service**: Authentication and user session management using FastAPI
- **Java Service**: PDF receipt generation with Spring Boot and iText library
- **Node.js**: Backend coordination and service orchestration
- **PostgreSQL**: Primary database with optimized schema design
- **Docker**: Containerization for all services with multi-stage builds
- **JWT Authentication**: Secure token-based authentication across services

## Getting Started

### Service Architecture

VuBank consists of multiple containerized microservices:

| Service | Technology | Port | Purpose | Status |
|---------|------------|------|---------|--------|
| Frontend | HTML/CSS/JS | 3001 | User interface and client-side logic | ✅ Active |
| Login Gateway | Go (Gin) | 8000 | Main API gateway and JWT management | ✅ Active |
| Auth Service | Python (FastAPI) | 8001 | User authentication and session management | ✅ Active |
| Accounts Service | Go (Gin) | 8002 | Account management and transaction data | ✅ Active |
| PDF Service | Java (Spring Boot) | 8003 | Professional PDF receipt generation | ✅ Active |
| Database | PostgreSQL 15 | 5432 | Data persistence and transaction storage | ✅ Active |

### Service Management

Use the integrated service management script for all operations:

```bash
# Check status of all services
./manage-services.sh status

# Start all services
./manage-services.sh start

# Stop all services  
./manage-services.sh stop

# View service logs
./manage-services.sh logs

# Run health checks
./manage-services.sh health
```

### Prerequisites
- **Docker** and **Docker Compose** (required for all services)
- **Maven 3.6+** (for PDF service development)
- **curl** (for health checks and API testing)
- **Git** (for repository management)

### Quick Start

**Option 1: Automated Setup (Recommended)**
```bash
# Clone and navigate to project
git clone <repository-url>
cd vuNGBank

# Install dependencies and start all services
./manage-services.sh install
./manage-services.sh start

# Check service status
./manage-services.sh status
```

**Option 2: Manual Docker Setup**
```bash
# Start all services using Docker Compose
docker compose up -d

# Build PDF service separately if needed
./build-pdf-service.sh

# Start frontend server
./frontend-server.sh start
```

### Access the Application
Once all services are running:
- **Banking Portal**: http://localhost:3001
- **API Gateway**: http://localhost:8000/health  
- **PDF Service**: http://localhost:8003/api/pdf/health
- **Service Status**: `./manage-services.sh status`

### Default Login Credentials
Use these test accounts for demonstration:
- **Retail User**: `johndoe` / `password123`
- **Corporate User**: `janedoe` / `password123`
- **Admin User**: `corpuser` / `password123`

## API Endpoints

### Authentication & Gateway (Port 8000)
- `POST /api/login` - User authentication with JWT token generation
- `GET /api/health` - Gateway service health check

### Account Management (Port 8002) 
- `GET /internal/accounts` - Get user accounts and transaction data (JWT required)
- `GET /health` - Accounts service health check

### PDF Receipt Generation (Port 8003)
- `POST /api/pdf/generate-receipt` - Generate transaction PDF receipt  
- `GET /api/pdf/health` - PDF service health check
- `GET /actuator/health` - Spring Boot actuator health endpoint

### Fund Transfer System
- **Multi-step Transfer Process**: Step-by-step fund transfer with validation
- **Payee Management**: Add and manage transfer recipients
- **Transaction Confirmation**: PIN verification and receipt generation
- **Real-time Balance Updates**: Account balance synchronization

### System Management
- `./manage-services.sh status` - Check all service statuses
- `./manage-services.sh health` - Run comprehensive health checks
- `./manage-services.sh logs` - View aggregated service logs

## Architecture

The application follows a **microservices architecture** with clear separation of concerns and containerized deployment:

### Frontend Layer
- **Technology**: Pure HTML5, CSS3, and vanilla JavaScript
- **Design**: VuBank-inspired interface with responsive layouts
- **Features**: Fund transfer workflow, dashboard, PDF receipt downloads
- **Authentication**: JWT token-based session management

### Microservices Layer
- **API Gateway (Go)**: Public-facing authentication and request routing
- **Authentication Service (Python)**: Secure credential verification and session management  
- **Account Service (Go)**: Account data management and transaction processing
- **PDF Service (Java)**: Professional receipt generation using Spring Boot and iText
- **Database Layer (PostgreSQL)**: Optimized schema with proper indexing

### Service Communication
- **JWT Authentication**: Stateless token-based security across services
- **Docker Networking**: Internal service communication
- **Health Monitoring**: Comprehensive health checks and status reporting
- **Error Handling**: Graceful degradation and error recovery

### Development Workflow
```bash
# Development cycle
./manage-services.sh start     # Start all services
# Make changes to code
./manage-services.sh restart   # Restart affected services
./manage-services.sh logs      # Monitor service logs
./manage-services.sh health    # Verify service health
```

## Synthetic Data

The application generates realistic banking data including:
- User accounts with different types (Current, Savings)
- Transaction history with various categories
- Realistic amounts and descriptions
- Date-based transaction patterns

## Security Features

- JWT token-based authentication
- Password hashing with bcrypt
- CORS configuration for secure cross-origin requests
- Input validation and sanitization
- Error handling middleware

## Development

### Service Development Scripts

**Service Management:**
```bash
# Service lifecycle
./manage-services.sh start     # Start all services
./manage-services.sh stop      # Stop all services  
./manage-services.sh restart   # Restart all services
./manage-services.sh status    # Check service status
./manage-services.sh logs      # View service logs
./manage-services.sh health    # Run health checks
```

**PDF Service Development:**
```bash
# Build PDF service locally
./build-pdf-service.sh

# Manual Maven build (if needed)
cd backend/services/pdf-receipt-java-service
mvn clean package
docker build -t pdf-receipt-service .
```

**Frontend Development:**
```bash
# Start frontend server manually
./frontend-server.sh start
./frontend-server.sh stop
./frontend-server.sh logs
```

### Available Service Endpoints

**Development Environment:**
- **Frontend**: http://localhost:3001
- **API Gateway**: http://localhost:8000
- **Auth Service**: http://localhost:8001 (internal)
- **Accounts Service**: http://localhost:8002 (internal)  
- **PDF Service**: http://localhost:8003
- **Database**: localhost:5432

**Health Check Endpoints:**
- Gateway: `curl http://localhost:8000/api/health`
- PDF Service: `curl http://localhost:8003/api/pdf/health`
- Accounts: `curl http://localhost:8002/health`

### Project Status

This is a **complete banking simulation platform** with:
- ✅ **Full Authentication System** - Multi-layer security with JWT
- ✅ **Fund Transfer Workflow** - Complete multi-step process
- ✅ **PDF Receipt Generation** - Professional transaction receipts  
- ✅ **Account Management** - Multiple account types and balances
- ✅ **Service Orchestration** - Docker-based microservices
- ✅ **Health Monitoring** - Comprehensive service monitoring
- ✅ **Synthetic Data** - Realistic banking test data

All financial data is synthetic and the system is designed for demonstration and testing purposes only.

## License

This project is for demonstration purposes only and should not be used for actual financial transactions.