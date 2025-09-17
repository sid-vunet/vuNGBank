# PostgreSQL Database Setup

This directory contains the database initialization scripts for VuBank's multi-service architecture.

## Database Schema

### Tables Created:
- **users**: User credentials and profile information
- **roles**: System roles (retail, corporate, admin)
- **user_roles**: User-role mapping
- **accounts**: Bank accounts linked to users
- **transactions**: Transaction history
- **login_requests**: Audit log for authentication attempts

### Default Users:
| Username | Email | Password | Role |
|----------|-------|----------|------|
| johndoe | john.doe@example.com | password123 | retail |
| janedoe | jane.doe@example.com | password123 | retail |
| corpuser | corporate@vubank.com | password123 | corporate |

### Connection Details:
- Database: vubank_db
- Port: 5432
- SSL Mode: disable (for local development)

### Usage:
The `init.sql` file is automatically executed when the PostgreSQL container starts up for the first time.

## Security Notes:
- Passwords are bcrypt hashed with cost factor 10
- All user operations are logged in login_requests table
- Foreign key constraints ensure data integrity
- Indexes are created for optimal query performance