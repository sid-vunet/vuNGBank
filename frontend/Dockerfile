FROM node:18-alpine

WORKDIR /app

# Install curl for health checks
RUN apk add --no-cache curl

# Copy package files
COPY package*.json ./

# Install dependencies (including express for our custom server)
RUN npm install --only=production

# Copy source code
COPY . .

# Build the React app
RUN npm run build

# Expose port
EXPOSE 3000

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:3000/healthcheck || exit 1

# Start our custom server that serves React app with health endpoints
CMD ["npm", "run", "serve"]