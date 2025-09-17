# VuBank NextGen Banking Platform

A full-stack banking simulation platform that mimics VuBank's Straight2Bank interface and operations using synthetic data.

## Project Structure

```
vuNGBank/
├── frontend/          # React-based frontend application
├── backend/           # Node.js/Express API server
└── .github/          # GitHub configuration
```

## Features

- **Authentication System**: User login with User ID/Email and Group ID
- **Dashboard Interface**: Modern banking dashboard matching SCB's design
- **Account Management**: Multiple account types with balance tracking
- **Transaction History**: Synthetic transaction data with realistic patterns
- **Microservices Architecture**: Modular backend services for different banking operations
- **Responsive Design**: Mobile-friendly interface
- **Synthetic Data**: Realistic banking data for testing and demonstration

## Technology Stack

### Frontend
- React 18.2.0
- Axios for API communication
- Material-UI components
- React Router for navigation
- CSS3 with custom styling matching SCB branding

### Backend
- Node.js with Express.js
- JWT authentication
- bcrypt for password hashing
- Faker.js for synthetic data generation
- CORS enabled for cross-origin requests

## Getting Started

### Prerequisites
- Node.js (version 16 or higher)
- npm or yarn package manager

### Installation

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