from fastapi import FastAPI, HTTPException, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import psycopg2
import psycopg2.extras
import bcrypt
import os
import logging
import hashlib
import secrets
import uuid
from datetime import datetime, timedelta
from typing import List, Optional

# Startup cleanup flag
_startup_cleanup_done = False

# Elastic APM imports
import elasticapm
from elasticapm.contrib.starlette import ElasticAPM, make_apm_client

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize comprehensive Elastic APM client (matching Go services and RUM)
apm_config = {
    'SERVICE_NAME': os.getenv('ELASTIC_APM_SERVICE_NAME', 'login-python-authenticator'),
    'SERVER_URL': os.getenv('ELASTIC_APM_SERVER_URL', 'http://91.203.133.240:30200'),
    'ENVIRONMENT': os.getenv('ELASTIC_APM_ENVIRONMENT', 'production'),
    'SERVICE_VERSION': os.getenv('ELASTIC_APM_SERVICE_VERSION', '1.0.0'),
    'TRANSACTION_SAMPLE_RATE': float(os.getenv('ELASTIC_APM_TRANSACTION_SAMPLE_RATE', '1.0')),
    'SPAN_SAMPLE_RATE': float(os.getenv('ELASTIC_APM_SPAN_SAMPLE_RATE', '1.0')),
    'CAPTURE_BODY': 'all',  # Comprehensive body capture like Go services
    'CAPTURE_HEADERS': False,  # Disable to avoid configuration issues
    'USE_DISTRIBUTED_TRACING': True,
    'DISTRIBUTED_TRACING_ORIGINS': ['*'],
    'STACK_TRACE_LIMIT': 50,
    'TRANSACTION_MAX_SPANS': 500,
    'LOG_LEVEL': 'info'
}

apm_client = make_apm_client(apm_config)
logger.info(f"Initialized APM client with server: {apm_config['SERVER_URL']}")

app = FastAPI(title="VuBank Authentication Service", version="1.0.0")

# Add Elastic APM middleware
app.add_middleware(ElasticAPM, client=apm_client)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Add startup event handler - MUST be after app creation but before route definitions
@app.on_event("startup")
async def startup_event():
    """Handle application startup tasks"""
    print("🚀 STARTUP EVENT TRIGGERED - VuBank Authentication Service starting up...")
    logger.info("🚀 STARTUP EVENT TRIGGERED - VuBank Authentication Service starting up...")
    
    try:
        # Call the session cleanup function
        print("🧹 Executing session cleanup...")
        logger.info("🧹 Executing session cleanup...")
        cleanup_sessions_on_startup()
        print("✅ Session cleanup completed successfully")
        logger.info("✅ VuBank Authentication Service startup completed successfully")
    except Exception as e:
        error_msg = f"❌ Error during startup: {e}"
        print(error_msg)
        logger.error(error_msg)
        # Don't raise the exception to prevent startup failure
        try:
            elasticapm.capture_exception()
        except Exception:
            pass

@app.on_event("shutdown")
async def shutdown_event():
    """Handle application shutdown tasks"""
    print("🛑 VuBank Authentication Service shutting down...")
    logger.info("🛑 VuBank Authentication Service shutting down...")

# Session cleanup function
def cleanup_sessions_on_startup():
    """
    Mark all active sessions as terminated when service starts
    This ensures clean session state after service restarts
    """
    print("🧹 Starting session cleanup process...")
    logger.info("🧹 Starting session cleanup process...")
    conn = None
    try:
        conn = get_db_connection()
        print("📊 Database connection established for session cleanup")
        logger.info("📊 Database connection established for session cleanup")
        
        with conn.cursor() as cursor:
            # Mark all active sessions as terminated due to service restart
            cursor.execute("""
                UPDATE active_sessions 
                SET is_active = FALSE, 
                    terminated_reason = %s, 
                    terminated_at = NOW()
                WHERE is_active = TRUE
            """, ("service_restart",))
            
            affected_rows = cursor.rowcount
            conn.commit()
            
            success_msg = f"✅ Session cleanup on startup: Terminated {affected_rows} active sessions due to service restart"
            print(success_msg)
            logger.info(success_msg)
            
    except Exception as e:
        error_msg = f"❌ Error during session cleanup on startup: {e}"
        print(error_msg)
        logger.error(error_msg)
        try:
            if conn:
                conn.rollback()
        except Exception as rollback_error:
            print(f"❌ Error during rollback: {rollback_error}")
            logger.error(f"❌ Error during rollback: {rollback_error}")
    finally:
        try:
            if conn:
                conn.close()
                print("📊 Database connection closed after session cleanup")
                logger.info("📊 Database connection closed after session cleanup")
        except Exception as close_error:
            print(f"❌ Error closing database connection: {close_error}")
            logger.error(f"❌ Error closing database connection: {close_error}")

# Pydantic models
class LoginRequest(BaseModel):
    username: str
    password: str
    force_login: Optional[bool] = False

class AuthResponse(BaseModel):
    ok: bool
    userId: Optional[str] = None
    roles: List[str] = []
    session_conflict: Optional[bool] = False
    existing_session: Optional[dict] = None
    session_id: Optional[str] = None

# Database configuration from environment
def get_db_config():
    return {
        'host': os.getenv('DB_HOST', 'localhost'),
        'port': int(os.getenv('DB_PORT', '5432')),
        'user': os.getenv('DB_USER', 'vubank_user'),
        'password': os.getenv('DB_PASSWORD', 'vubank_pass'),
        'database': os.getenv('DB_NAME', 'vubank_db'),
        'sslmode': os.getenv('DB_SSLMODE', 'disable')
    }

# Database connection
def get_db_connection():
    try:
        config = get_db_config()
        conn = psycopg2.connect(**config)
        return conn
    except Exception as e:
        logger.error(f"Database connection failed: {e}")
        raise HTTPException(status_code=500, detail="Database connection failed")

# Verify password using bcrypt
def verify_password(plain_password: str, hashed_password: str) -> bool:
    try:
        return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))
    except Exception as e:
        logger.error(f"Password verification failed: {e}")
        return False

# Generate session ID
def generate_session_id() -> str:
    return str(uuid.uuid4())

# Check for existing active sessions for a user
def check_existing_session(user_id: int):
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
            cursor.execute("""
                SELECT session_id, created_at, ip_address, user_agent 
                FROM active_sessions 
                WHERE user_id = %s AND is_active = TRUE AND expires_at > NOW()
            """, (user_id,))
            return cursor.fetchone()
    except Exception as e:
        logger.error(f"Error checking existing session: {e}")
        return None
    finally:
        conn.close()

# Terminate existing sessions for a user
def terminate_user_sessions(user_id: int, reason: str = "New login"):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                UPDATE active_sessions 
                SET is_active = FALSE, terminated_reason = %s, terminated_at = NOW()
                WHERE user_id = %s AND is_active = TRUE
            """, (reason, user_id))
            conn.commit()
            logger.info(f"Terminated existing sessions for user {user_id}: {reason}")
    except Exception as e:
        logger.error(f"Error terminating sessions: {e}")
        conn.rollback()
    finally:
        conn.close()

# Create new session
def create_session(user_id: int, session_id: str, jwt_hash: str, ip_address: str, user_agent: str):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            expires_at = datetime.now() + timedelta(hours=24)  # 24-hour session
            # Handle IP address and user agent - use NULL for 'unknown' or empty to avoid INET type issues
            ip_addr = None if ip_address in ["unknown", ""] else ip_address
            user_agent_val = None if user_agent in ["unknown", ""] else user_agent
            
            cursor.execute("""
                INSERT INTO active_sessions 
                (user_id, session_id, jwt_token_hash, ip_address, user_agent, expires_at)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, (user_id, session_id, jwt_hash, ip_addr, user_agent_val, expires_at))
            conn.commit()
            logger.info(f"Created new session {session_id} for user {user_id}")
    except Exception as e:
        logger.error(f"Error creating session: {e}")
        try:
            conn.rollback()
        except Exception:
            pass
        raise
    finally:
        conn.close()

# Hash JWT token for storage
def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()

# Get user by username with roles
def get_user_with_roles(username: str):
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cursor:
            query = """
                SELECT 
                    u.id, u.username, u.email, u.password_hash, u.is_active,
                    COALESCE(array_agg(r.name) FILTER (WHERE r.name IS NOT NULL), ARRAY[]::varchar[]) as roles
                FROM users u
                LEFT JOIN user_roles ur ON u.id = ur.user_id
                LEFT JOIN roles r ON ur.role_id = r.id
                WHERE u.username = %s
                GROUP BY u.id, u.username, u.email, u.password_hash, u.is_active
            """
            cursor.execute(query, (username,))
            return cursor.fetchone()
    except Exception as e:
        logger.error(f"Database query failed: {e}")
        raise HTTPException(status_code=500, detail="Database query failed")
    finally:
        conn.close()

# Log authentication attempt
def log_auth_attempt(user_id: Optional[int], username: str, success: bool, 
                     ip_address: str, user_agent: str, request_id: str, 
                     failure_reason: Optional[str] = None):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Handle IP address - use NULL for 'unknown' or invalid IPs to avoid INET type issues
            ip_addr = None if ip_address in ["unknown", ""] else ip_address
            user_agent_val = None if user_agent in ["unknown", ""] else user_agent
            
            query = """
                INSERT INTO login_requests 
                (user_id, username, ip_address, user_agent, success, failure_reason, request_id)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
            """
            cursor.execute(query, (user_id, username, ip_addr, user_agent_val, success, failure_reason, request_id))
            conn.commit()
    except Exception as e:
        logger.error(f"Failed to log authentication attempt: {e}")
        # Don't re-raise the exception - authentication should continue even if logging fails
        try:
            conn.rollback()
        except Exception:
            pass
    finally:
        conn.close()

@app.get("/health")
async def health_check():
    """Health check endpoint with startup cleanup"""
    global _startup_cleanup_done
    
    try:
        # Perform startup cleanup on first health check call
        if not _startup_cleanup_done:
            print("🚀 First health check - performing startup session cleanup...")
            logger.info("🚀 First health check - performing startup session cleanup...")
            try:
                cleanup_sessions_on_startup()
                _startup_cleanup_done = True
                print("✅ Startup cleanup completed on first health check")
                logger.info("✅ Startup cleanup completed on first health check")
            except Exception as cleanup_error:
                error_msg = f"❌ Startup cleanup failed on health check: {cleanup_error}"
                print(error_msg)
                logger.error(error_msg)
                # Don't fail health check due to cleanup failure, but retry next time
        
        # Regular health check
        conn = get_db_connection()
        with conn.cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
        conn.close()
        
        return {
            "status": "healthy", 
            "database": "connected",
            "startup_cleanup_done": _startup_cleanup_done
        }
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return {"status": "unhealthy", "database": "disconnected", "error": str(e)}

@app.post("/verify", response_model=AuthResponse)
async def verify_credentials(
    request: LoginRequest,
    x_request_id: Optional[str] = Header(None),
    x_forwarded_for: Optional[str] = Header(None),
    user_agent: Optional[str] = Header(None)
):
    """
    Verify user credentials and return authentication response
    """    
    logger.info(f"Authentication attempt for username: {request.username}, force_login: {request.force_login}")
    
    # Get client IP and user agent (would be passed from gateway)
    client_ip = x_forwarded_for or "unknown"
    client_user_agent = user_agent or "unknown"
    request_id = x_request_id or "unknown"
    
    try:
        # Get user with roles
        user = get_user_with_roles(request.username)
        
        if not user:
            logger.warning(f"User not found: {request.username}")
            log_auth_attempt(None, request.username, False, client_ip, client_user_agent, request_id, "user_not_found")
            return AuthResponse(ok=False)
        
        # Check if user is active
        if not user['is_active']:
            logger.warning(f"Inactive user login attempt: {request.username}")
            log_auth_attempt(user['id'], request.username, False, client_ip, client_user_agent, request_id, "user_inactive")
            return AuthResponse(ok=False)
        
        # Verify password
        if not verify_password(request.password, user['password_hash']):
            logger.warning(f"Invalid password for user: {request.username}")
            log_auth_attempt(user['id'], request.username, False, client_ip, client_user_agent, request_id, "invalid_password")
            return AuthResponse(ok=False)
        
        # Check for existing active session
        existing_session = check_existing_session(user['id'])
        
        if existing_session and not request.force_login:
            logger.info(f"Session conflict detected for user: {request.username}")
            log_auth_attempt(user['id'], request.username, False, client_ip, client_user_agent, request_id, "session_conflict")
            return AuthResponse(
                ok=False,
                session_conflict=True,
                existing_session={
                    "created_at": existing_session['created_at'].isoformat(),
                    "ip_address": str(existing_session['ip_address']) if existing_session['ip_address'] else "unknown",
                    "user_agent": existing_session['user_agent'] or "unknown"
                }
            )
        
        # If force login is requested, terminate existing sessions
        if existing_session and request.force_login:
            terminate_user_sessions(user['id'], "Forced login from new session")
            logger.info(f"Forced login - terminated existing session for user: {request.username}")
        
        # Generate new session
        session_id = generate_session_id()
        
        # Success - create session (JWT hash will be provided later by login service)
        logger.info(f"Successful authentication for user: {request.username}")
        log_auth_attempt(user['id'], request.username, True, client_ip, client_user_agent, request_id)
        
        return AuthResponse(
            ok=True,
            userId=str(user['id']),
            roles=user['roles'] if user['roles'] else [],
            session_id=session_id
        )
        
    except Exception as e:
        logger.error(f"Authentication error: {e}")
        log_auth_attempt(None, request.username, False, client_ip, client_user_agent, request_id, f"system_error: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal authentication error")

# New session creation endpoint
class SessionRequest(BaseModel):
    user_id: int
    session_id: str
    jwt_token: str
    ip_address: Optional[str] = "unknown"
    user_agent: Optional[str] = "unknown"

@app.post("/create-session")
async def create_user_session(request: SessionRequest):
    """
    Create a new active session record after JWT generation
    """
    try:
        jwt_hash = hash_token(request.jwt_token)
        
        create_session(
            request.user_id, 
            request.session_id, 
            jwt_hash, 
            request.ip_address, 
            request.user_agent
        )
        
        return {"success": True, "message": "Session created successfully"}
    except Exception as e:
        logger.error(f"Error creating session: {e}")
        raise HTTPException(status_code=500, detail="Failed to create session")

# Session validation endpoint
@app.post("/validate-session")
async def validate_session(session_id: str, jwt_token: str):
    """
    Validate if a session is still active and JWT matches
    """
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
            jwt_hash = hash_token(jwt_token)
            cursor.execute("""
                SELECT user_id, expires_at, is_active 
                FROM active_sessions 
                WHERE session_id = %s AND jwt_token_hash = %s
            """, (session_id, jwt_hash))
            
            session = cursor.fetchone()
            if not session:
                return {"valid": False, "reason": "session_not_found"}
            
            if not session['is_active']:
                return {"valid": False, "reason": "session_terminated"}
            
            if session['expires_at'] < datetime.now():
                return {"valid": False, "reason": "session_expired"}
            
            return {"valid": True, "user_id": session['user_id']}
    except Exception as e:
        logger.error(f"Session validation error: {e}")
        return {"valid": False, "reason": "validation_error"}
    finally:
        conn.close()

# Logout endpoint
class LogoutRequest(BaseModel):
    user_id: int
    session_id: Optional[str] = None
    terminate_all_sessions: Optional[bool] = False

@app.post("/logout")
async def logout_user(request: LogoutRequest):
    """
    Terminate user session(s) and log the logout event
    """
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            if request.terminate_all_sessions or not request.session_id:
                # Terminate all active sessions for the user
                cursor.execute("""
                    UPDATE active_sessions 
                    SET is_active = FALSE, terminated_reason = %s, terminated_at = NOW()
                    WHERE user_id = %s AND is_active = TRUE
                """, ("User logout", request.user_id))
                affected_rows = cursor.rowcount
                logger.info(f"Terminated {affected_rows} sessions for user {request.user_id}")
            else:
                # Terminate specific session
                cursor.execute("""
                    UPDATE active_sessions 
                    SET is_active = FALSE, terminated_reason = %s, terminated_at = NOW()
                    WHERE user_id = %s AND session_id = %s AND is_active = TRUE
                """, ("User logout", request.user_id, request.session_id))
                affected_rows = cursor.rowcount
                logger.info(f"Terminated session {request.session_id} for user {request.user_id}")
            
            conn.commit()
            
            return {
                "success": True, 
                "message": "Logout successful",
                "sessions_terminated": affected_rows
            }
    except Exception as e:
        logger.error(f"Logout error: {e}")
        conn.rollback()
        raise HTTPException(status_code=500, detail="Logout failed")
    finally:
        conn.close()

if __name__ == "__main__":
    import uvicorn
    
    # Perform session cleanup before starting the server
    logger.info("🚀 VuBank Authentication Service starting up...")
    try:
        cleanup_sessions_on_startup()
        logger.info("✅ Session cleanup completed, starting server...")
    except Exception as e:
        logger.error(f"❌ Error during session cleanup: {e}")
        # Continue starting the server anyway
    
    port = int(os.getenv('PUBLIC_API_PORT', '8001'))
    uvicorn.run(app, host="0.0.0.0", port=port)