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

# Initialize minimal APM client
print("🔧 Initializing minimal APM configuration for Python Auth service...")

apm_config = {
    # Core service identification only
    'SERVICE_NAME': 'login-python-authenticator',
    'SERVER_URL': 'http://91.203.133.240:30200',
    'ENVIRONMENT': 'production',
}

try:
    apm_client = make_apm_client(apm_config)
    print("✅ Minimal APM Configuration Applied Successfully")
    print(f"   Service: {amp_config['SERVICE_NAME']}")
    print(f"   Server: {apm_config['SERVER_URL']}")
except Exception as e:
    print(f"❌ APM Configuration Failed: {e}")
    print("   Proceeding without APM...")
    apm_client = None

logger.info(f"Initialized minimal APM client")

app = FastAPI(
    title="VuNG Bank - Login & Authentication Service",
    description="Python-based microservice for secure user authentication with comprehensive APM monitoring", 
    version="1.0.0"
)

print("✅ FastAPI app initialized")
print("🚀 Python authenticator service ready to start!")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8080, reload=True)