# VuBank HTML Frontend Container Guide

## 🎯 **Traditional Multi-Page Application in Docker Container**

This setup runs your HTML banking pages (index.html, login.html, dashboard.html, FundTransfer.html) as a traditional multi-page application inside an Nginx Docker container.

## 🚀 **Quick Start**

### **Option 1: Use the Management Script (Recommended)**
```bash
# Start all services with HTML frontend in container
./manage-services.sh start html-container

# Check status
./manage-services.sh status

# View logs
./manage-services.sh logs
```

### **Option 2: Direct Docker Commands**
```bash
# Build the HTML container
cd frontend && ./build-html-container.sh

# Start with docker-compose profile
docker-compose --profile html-frontend up -d

# Or run the container manually
docker run -d -p 3001:80 --name vubank-html-frontend vubank-html-frontend
```

## 📋 **Available Frontend Options**

| Option | Command | Description | Port | Use Case |
|--------|---------|-------------|------|----------|
| **HTML Server** | `./manage-services.sh start` | Simple Python HTTP server | 3001 | Development, testing |
| **HTML Container** | `./manage-services.sh start html-container` | Nginx container with HTML pages | 3001 | Production-like multi-page app |
| **React Container** | `./manage-services.sh start react-container` | React SPA in container | 3000 | Modern SPA experience |

## 🌐 **HTML Container Features**

### **Available Pages:**
- **Home:** http://localhost:3001/
- **Login:** http://localhost:3001/login (or /login.html)
- **Dashboard:** http://localhost:3001/dashboard (or /dashboard.html) 
- **Transfer:** http://localhost:3001/transfer (or /FundTransfer.html)
- **Health Check:** http://localhost:3001/health

### **Built-in Features:**
- ✅ **Nginx Web Server** - Production-ready static file serving
- ✅ **Clean URLs** - `/login` instead of `/login.html`
- ✅ **CORS Headers** - Pre-configured for API calls
- ✅ **Security Headers** - XSS protection, frame options, etc.
- ✅ **Gzip Compression** - Optimized file delivery
- ✅ **Health Checks** - Container health monitoring
- ✅ **API Proxy** - Optional `/api/` proxying to backend
- ✅ **Static Asset Caching** - 1-year cache for CSS/JS/images

### **RUM Integration:**
The HTML pages include RUM (Real User Monitoring) configuration in each page that connects to your APM server for distributed tracing.

## 🔧 **Container Configuration**

### **Dockerfile.html:**
- Based on `nginx:alpine` (lightweight)
- Copies HTML files to nginx document root
- Uses custom nginx configuration
- Exposes port 80 (mapped to 3001)

### **nginx.conf:**
- Serves static HTML files
- Provides clean URL routing
- Handles CORS for API calls
- Includes security headers
- Optional API proxying

## 🏗 **Architecture Benefits**

### **Traditional Multi-Page App in Container:**
```
Browser → Nginx Container (port 3001) → Static HTML Pages
   ↓
API Calls → Go Login Service (port 8000) → Backend Services
```

### **Advantages:**
- ✅ **Fast Loading** - Each page loads independently
- ✅ **SEO Friendly** - Each page has its own URL and content
- ✅ **Simple Debugging** - Easy to trace issues per page
- ✅ **Container Benefits** - Scalable, portable, production-ready
- ✅ **Banking UX** - Traditional banking interface patterns
- ✅ **RUM Per Page** - Individual page monitoring
- ✅ **Nginx Performance** - Production-grade web server

## 🧪 **Testing the Setup**

### **1. Build and Start:**
```bash
./manage-services.sh start html-container
```

### **2. Test Pages:**
```bash
# Test home page
curl -s http://localhost:3001/ | grep -o '<title>.*</title>'

# Test login page  
curl -s http://localhost:3001/login | grep -o '<title>.*</title>'

# Test health endpoint
curl http://localhost:3001/health
```

### **3. Test RUM Integration:**
1. Open http://localhost:3001/login in browser
2. Perform login with real user interaction
3. Check APM Dashboard for RUM transactions
4. Verify distributed traces from frontend to backend

## 📊 **Monitoring & Logs**

### **Container Logs:**
```bash
# View HTML frontend container logs
docker logs vubank-html-frontend

# Follow logs in real-time
docker logs -f vubank-html-frontend

# Using manage script
./manage-services.sh logs
```

### **Health Monitoring:**
```bash
# Check container health
docker ps | grep vubank-html-frontend

# Test health endpoint
curl http://localhost:3001/health
```

## 🔄 **Switching Between Frontend Options**

```bash
# Stop current setup
./manage-services.sh stop

# Start with different frontend
./manage-services.sh start html-container    # Nginx container
./manage-services.sh start react-container   # React SPA
./manage-services.sh start                   # Python server (default)
```

## 🎯 **Production Deployment**

This HTML container setup is production-ready:
- Nginx handles high concurrent connections
- Static files are efficiently served
- Security headers are configured
- Health checks enable load balancer integration
- CORS is properly configured for API calls
- RUM provides real user monitoring

Perfect for traditional banking applications that need reliable, fast-loading pages with modern observability! 🏦✨