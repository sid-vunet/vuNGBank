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

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

print("🔧 Initializing Python Auth service without APM...")

# Database connection
def get_database_connection():
    return psycopg2.connect(
        host=os.getenv('DB_HOST', 'vubank-postgres'),
        port=os.getenv('DB_PORT', '5432'), 
        database=os.getenv('DB_NAME', 'vungbank'),
        user=os.getenv('DB_USER', 'vungbank'),
        password=os.getenv('DB_PASSWORD', 'vungbank123')
    )

app = FastAPI(
    title="VuNG Bank - Login & Authentication Service",
    description="Python-based microservice for secure user authentication", 
    version="1.0.0"
)

# CORS configuration 
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Health check endpoint
@app.get("/health")
async def health_check():
    try:
        conn = get_database_connection()
        conn.close()
        return {
            "status": "healthy",
            "service": "login-python-authenticator",
            "version": "1.0.0",
            "database": "connected"
        }
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Database connection failed: {str(e)}")

# Simple login endpoint for testing
@app.post("/api/login")
async def login():
    return {
        "message": "Python authenticator service is running",
        "service": "login-python-authenticator",
        "status": "operational"
    }

print("✅ FastAPI app initialized without APM")
print("🚀 Python authenticator service ready to start!")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8080, reload=True)