# Kong Gateway with Elastic APM Plugin for VuNG Bank
FROM kong:3.8.0

# Switch to root to install dependencies
USER root

# Install basic dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Create plugin directory (for future custom plugins)
RUN mkdir -p /usr/local/share/lua/5.1/kong/plugins/elastic-apm

# Copy custom Elastic APM plugin (simplified version)
COPY plugins/elastic-apm/ /usr/local/share/lua/5.1/kong/plugins/elastic-apm/

# Copy Kong configuration
COPY kong-declarative.yml /etc/kong/kong.yml
COPY kong.conf /etc/kong/kong.conf

# Create directories for logs and runtime
RUN mkdir -p /var/log/kong \
    && mkdir -p /usr/local/kong/logs \
    && chown -R kong:kong /var/log/kong \
    && chown -R kong:kong /usr/local/kong/logs \
    && chown -R kong:kong /etc/kong

# Switch back to kong user
USER kong

# Set environment variables
ENV KONG_DATABASE=postgres
ENV KONG_PG_HOST=kong-postgres
ENV KONG_PG_PORT=5432
ENV KONG_PG_USER=kong
ENV KONG_PG_PASSWORD=kong_pass
ENV KONG_PG_DATABASE=kong
ENV KONG_PROXY_ACCESS_LOG=/dev/stdout
ENV KONG_ADMIN_ACCESS_LOG=/dev/stdout
ENV KONG_PROXY_ERROR_LOG=/dev/stderr
ENV KONG_ADMIN_ERROR_LOG=/dev/stderr
ENV KONG_ADMIN_LISTEN=0.0.0.0:8001
ENV KONG_PROXY_LISTEN=0.0.0.0:8086
ENV KONG_PLUGINS=bundled,elastic-apm
ENV KONG_LOG_LEVEL=info

# Health check
HEALTHCHECK --interval=10s --timeout=10s --retries=3 \
    CMD kong health

# Expose ports
EXPOSE 8086 8001

# Start Kong
CMD ["kong", "docker-start"]