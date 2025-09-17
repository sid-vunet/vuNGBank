# VuBank NextGen Banking Platform - Coding Style Guide

## General Principles

### Code Philosophy
- **Clarity over Cleverness**: Write code that is easy to understand
- **Consistency**: Follow established patterns throughout the codebase
- **Defensive Programming**: Handle errors gracefully
- **Performance Awareness**: Write efficient code without premature optimization
- **Security First**: Consider security implications in every decision

### Documentation Standards
- **Self-Documenting Code**: Use clear names and structure
- **Comment Purpose**: Explain why, not what
- **API Documentation**: Clear endpoint descriptions
- **README Files**: Comprehensive setup and usage instructions

## Language-Specific Guidelines

### Go Style (Gateway & Accounts Services)

#### File Organization
```go
package main

// Standard library imports first
import (
    "context"
    "log"
    "net/http"
)

// Third-party imports
import (
    "github.com/gin-gonic/gin"
    "github.com/golang-jwt/jwt/v5"
)

// Local imports last
import (
    "./internal/auth"
    "./internal/config"
)
```

#### Naming Conventions
- **Variables**: camelCase (`userName`, `accountBalance`)
- **Constants**: UPPER_SNAKE_CASE (`JWT_SECRET`, `DEFAULT_PORT`)
- **Functions**: PascalCase for exported (`GetUserAccounts`), camelCase for private (`validateToken`)
- **Structs**: PascalCase (`UserAccount`, `TransactionRecord`)
- **Interfaces**: PascalCase with -er suffix when appropriate (`TokenValidator`)

#### Error Handling
```go
// Preferred: Explicit error checking
result, err := performOperation()
if err != nil {
    log.Printf("Operation failed: %v", err)
    return fmt.Errorf("failed to perform operation: %w", err)
}

// Use structured error responses
type ErrorResponse struct {
    Error   string `json:"error"`
    Message string `json:"message"`
}
```

#### HTTP Handler Pattern
```go
func handlerName(dependencies) gin.HandlerFunc {
    return func(c *gin.Context) {
        // Validate input
        // Process business logic
        // Return response
        c.JSON(http.StatusOK, response)
    }
}
```

#### Configuration Pattern
```go
type Config struct {
    Port      string
    JWTSecret string
    DBConfig  DBConfig
}

func loadConfig() *Config {
    return &Config{
        Port:      getEnv("PORT", "8000"),
        JWTSecret: getEnv("JWT_SECRET", "default-secret"),
    }
}
```

### Python Style (Authentication Service)

#### Import Organization
```python
# Standard library
import os
import logging
from datetime import datetime
from typing import List, Optional

# Third-party
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import psycopg2
import bcrypt

# Local imports
from .config import get_db_config
from .models import UserModel
```

#### Naming Conventions
- **Variables/Functions**: snake_case (`user_name`, `get_user_accounts`)
- **Constants**: UPPER_SNAKE_CASE (`DB_HOST`, `JWT_SECRET`)
- **Classes**: PascalCase (`UserAccount`, `AuthResponse`)
- **Private Methods**: Leading underscore (`_validate_token`)

#### Error Handling
```python
# Use FastAPI HTTPException for API errors
if not user:
    logger.warning(f"User not found: {username}")
    raise HTTPException(
        status_code=404,
        detail="User not found"
    )

# Use try-except for database operations
try:
    result = perform_database_operation()
except psycopg2.Error as e:
    logger.error(f"Database error: {e}")
    raise HTTPException(
        status_code=500,
        detail="Database operation failed"
    )
```

#### Pydantic Models
```python
class AuthRequest(BaseModel):
    username: str
    password: str
    force_login: Optional[bool] = False

    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }
```

### React/JavaScript Style (Frontend)

#### Component Structure
```javascript
// Functional components with hooks
const ComponentName = ({ prop1, prop2 }) => {
  // State declarations
  const [state, setState] = useState(initialValue);
  
  // Effect hooks
  useEffect(() => {
    // Side effects
  }, [dependencies]);
  
  // Event handlers
  const handleEvent = (event) => {
    // Handle event
  };
  
  // Render
  return (
    <div className="component-name">
      {/* JSX content */}
    </div>
  );
};
```

#### Naming Conventions
- **Components**: PascalCase (`LoginPage`, `Dashboard`)
- **Functions**: camelCase (`handleLogin`, `fetchAccountData`)
- **Variables**: camelCase (`userData`, `isLoading`)
- **Constants**: UPPER_SNAKE_CASE (`API_BASE_URL`)
- **CSS Classes**: kebab-case (`login-container`, `dashboard-card`)

#### State Management
```javascript
// Prefer multiple useState over single complex state
const [user, setUser] = useState(null);
const [isLoading, setIsLoading] = useState(false);
const [error, setError] = useState('');

// Not: const [state, setState] = useState({user: null, isLoading: false, error: ''});
```

#### Error Handling
```javascript
const fetchData = async () => {
  try {
    setIsLoading(true);
    setError('');
    
    const response = await fetch(apiUrl);
    if (!response.ok) {
      throw new Error('Failed to fetch data');
    }
    
    const data = await response.json();
    setData(data);
  } catch (error) {
    console.error('Error fetching data:', error);
    setError(error.message);
  } finally {
    setIsLoading(false);
  }
};
```

## Database Style (PostgreSQL)

### Schema Design
```sql
-- Table names: snake_case, plural
CREATE TABLE user_accounts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    account_number VARCHAR(20) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Column names: snake_case
-- Use descriptive names: created_at, not created
-- Use consistent patterns: _id for foreign keys
```

### Query Style
```sql
-- Use consistent formatting
SELECT 
    u.username,
    a.account_number,
    a.balance
FROM users u
JOIN accounts a ON u.id = a.user_id
WHERE u.is_active = TRUE
ORDER BY u.created_at DESC;

-- Use explicit JOIN syntax
-- Alias tables consistently
-- Use meaningful WHERE conditions
```

### Index Naming
```sql
-- Pattern: idx_tablename_columnname
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_accounts_user_id ON accounts(user_id);
CREATE INDEX idx_transactions_account_id ON transactions(account_id);
```

## API Design Patterns

### Request/Response Structure
```javascript
// Request format
{
  "username": "johndoe",
  "password": "secure_password"
}

// Success response format
{
  "token": "jwt_token_here",
  "user": {
    "id": "123",
    "username": "johndoe",
    "roles": ["retail"]
  }
}

// Error response format
{
  "error": "invalid_credentials",
  "message": "Invalid username or password"
}
```

### HTTP Status Code Usage
- `200 OK`: Successful GET, PUT, PATCH
- `201 Created`: Successful POST with resource creation
- `400 Bad Request`: Client error, invalid input
- `401 Unauthorized`: Missing or invalid authentication
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: Resource not found
- `409 Conflict`: Resource conflict (e.g., session conflict)
- `500 Internal Server Error`: Server-side errors

## Security Guidelines

### Input Validation
```javascript
// Validate all inputs
const validateInput = (data) => {
  if (!data.username || data.username.length < 3) {
    throw new Error('Username must be at least 3 characters');
  }
  
  if (!data.password || data.password.length < 8) {
    throw new Error('Password must be at least 8 characters');
  }
};
```

### SQL Query Safety
```python
# Use parameterized queries
cursor.execute(
    "SELECT * FROM users WHERE username = %s",
    (username,)
)

# Never use string concatenation
# cursor.execute(f"SELECT * FROM users WHERE username = '{username}'")  # DON'T
```

### Environment Variables
```bash
# Use descriptive names
DB_HOST=localhost
DB_PORT=5432
JWT_SECRET=your-super-secret-key

# Not: HOST=localhost, SECRET=key
```

## Testing Patterns

### Unit Test Structure
```javascript
describe('Component Name', () => {
  beforeEach(() => {
    // Setup
  });

  it('should handle specific scenario', () => {
    // Arrange
    const input = 'test data';
    
    // Act
    const result = functionUnderTest(input);
    
    // Assert
    expect(result).toBe(expected);
  });
});
```

### API Testing
```python
def test_login_success():
    # Arrange
    user_data = {"username": "testuser", "password": "password123"}
    
    # Act
    response = client.post("/api/login", json=user_data)
    
    # Assert
    assert response.status_code == 200
    assert "token" in response.json()
```

## Performance Guidelines

### Database Queries
- Use indexes for frequently queried columns
- Limit result sets with LIMIT clause
- Use EXPLAIN to analyze query performance
- Avoid N+1 query problems

### Frontend Performance
- Use React.memo for expensive components
- Implement proper loading states
- Optimize bundle size with code splitting
- Cache API responses when appropriate

### Backend Performance
- Use connection pooling for databases
- Implement proper error handling
- Use middleware for common operations
- Monitor memory usage and connections

## Documentation Standards

### Code Comments
```go
// VerifyCredentials validates user login credentials and returns authentication status.
// It performs bcrypt password verification and checks user account status.
// Returns error if credentials are invalid or user account is disabled.
func VerifyCredentials(username, password string) (*User, error) {
    // Implementation
}
```

### API Documentation
```yaml
# OpenAPI/Swagger format preferred
/api/login:
  post:
    summary: Authenticate user login
    parameters:
      - name: username
        required: true
        type: string
    responses:
      200:
        description: Login successful
      401:
        description: Invalid credentials
```

### README Structure
```markdown
# Service Name

## Overview
Brief description of the service

## Setup
Step-by-step setup instructions

## API Endpoints
List of available endpoints

## Configuration
Environment variables and configuration options

## Testing
How to run tests
```