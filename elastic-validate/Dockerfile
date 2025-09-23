# Build stage
FROM golang:1.21-alpine AS builder

# Install git for go mod download
RUN apk add --no-cache git

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags="-s -w" -o elastic-validate ./main.go

# Final stage
FROM alpine:latest

# Add ca-certificates for HTTPS requests
RUN apk --no-cache add ca-certificates

# Create non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

WORKDIR /root/

# Copy the binary from builder stage
COPY --from=builder /app/elastic-validate .

# Change ownership to non-root user
RUN chown appuser:appgroup ./elastic-validate

# Switch to non-root user
USER appuser

# Expose port (if needed)
# EXPOSE 8080

# Set default command
ENTRYPOINT ["./elastic-validate"]

# Default to health check
CMD ["health", "--check-all"]