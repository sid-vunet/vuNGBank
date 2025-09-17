# VuBank NextGen Banking Platform

A full-stack banking simulation platform that mimics VuBank's Straight2Bank interface and operations using synthetic data.

## Project Structure

```
vuNGBank/
├── frontend/          # React-based frontend application
├── backend/           # Node.js/Express API server
├── docs/              # Comprehensive project documentation
└── .github/          # GitHub configuration
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

- **Authentication System**: User login with User ID/Email and Group ID
- **Dashboard Interface**: Modern banking dashboard matching VuBank's design
- **Account Management**: Multiple account types with balance tracking
- **Fund Transfer System**: Complete multi-step transfer process with payee management
- **PDF Receipt Generation**: Professional PDF receipts for transactions
- **Transaction History**: Synthetic transaction data with realistic patterns
- **Microservices Architecture**: Modular backend services for different banking operations
- **Responsive Design**: Mobile-friendly interface
- **Synthetic Data**: Realistic banking data for testing and demonstration

## Technology Stack

### Frontend
- HTML5 with vanilla JavaScript
- Modern CSS3 with custom styling matching VuBank branding
- Responsive design principles
- AJAX for API communication

### Backend Microservices
- **Go Services**: Login gateway and accounts service
- **Python Service**: Authentication and user management
- **Java Service**: PDF receipt generation with iText
- **Node.js**: Main backend coordination
- **PostgreSQL**: Primary database
- JWT authentication across services
- Docker containerization for all services

## Getting Started

### Service Architecture

VuBank consists of multiple microservices:

| Service | Technology | Port | Purpose |
|---------|------------|------|---------|
| Frontend | HTML/CSS/JS | 3001 | User interface |
| Login Gateway | Go | 8000 | Main API gateway |
| Auth Service | Python | 8001 | User authentication |
| Accounts Service | Go | 8002 | Account management |
| PDF Service | Java/Spring Boot | 8003 | Receipt generation |
| Database | PostgreSQL | 5432 | Data persistence |

### Prerequisites
- Docker and Docker Compose
- Maven (for PDF service)
- Node.js 16+ (for optional React frontend)

### Quick Start

1. **Start All Services**
   ```bash
   # Clone and navigate to project
   cd vuNGBank
   
   # Start all services using Docker Compose
   ./manage-services.sh start
   ```

2. **Build PDF Service (if needed)**
   ```bash
   # Build the Java PDF service separately
   ./build-pdf-service.sh
   ```

3. **Access the Application**
   - **Frontend**: http://localhost:3001
   - **API Gateway**: http://localhost:8000
   - **PDF Service**: http://localhost:8003

### Manual Installation (Alternative)

1. **Install Backend Dependencies**
   ```bash
   cd backend
   npm install
   ```

2. **Install Frontend Dependencies**
   ```bash
   cd frontend
   npm install
   ```

### Running the Application

1. **Start the Backend Server**
   ```bash
   cd backend
   npm run dev
   ```
   The API server will start on `http://localhost:5000`

2. **Start the Frontend Application**
   ```bash
   cd frontend
   npm start
   ```
   The React app will start on `http://localhost:3000`

### Default Login Credentials

For testing purposes, you can use:
- **User ID**: `johndoe123` or `john.doe@example.com`
- **Group ID**: `CORPORATE` (optional)

## API Endpoints

### Authentication
- `POST /api/auth/login` - User login

### User Management
- `GET /api/user/profile` - Get user profile (authenticated)

### Account Services
- `GET /api/accounts` - Get user accounts (authenticated)
- `GET /api/accounts/:id/transactions` - Get account transactions (authenticated)

### Transaction Services
- `POST /api/transactions/transfer` - Transfer money (authenticated)

### System
- `GET /health` - Health check endpoint
- `GET /` - API documentation

## Architecture

The application follows a microservices architecture with clear separation of concerns:

### Frontend Components
- `LoginPage`: Authentication interface matching SCB design
- `Dashboard`: Main banking dashboard with account overview
- `App`: Main application component with routing logic

### Backend Services
- **Authentication Service**: JWT-based user authentication
- **Account Service**: Account management and balance tracking  
- **Transaction Service**: Transaction processing and history
- **Data Generation Service**: Synthetic data creation using Faker.js

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

### Available Scripts

**Frontend:**
- `npm start` - Start development server
- `npm build` - Build for production
- `npm test` - Run tests

**Backend:**
- `npm run dev` - Start with nodemon (auto-reload)
- `npm start` - Start production server
- `npm test` - Run tests

### Project Status

This project simulates a complete banking platform for demonstration and testing purposes. All financial data is synthetic and no real banking operations are performed.

## License

This project is for demonstration purposes only and should not be used for actual financial transactions.