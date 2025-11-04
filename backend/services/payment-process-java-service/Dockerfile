FROM eclipse-temurin:17-jdk-jammy

# Set working directory
WORKDIR /app

# Install Maven and curl for health checks
RUN apt-get update && apt-get install -y maven curl && rm -rf /var/lib/apt/lists/*

# Copy pom.xml and download dependencies
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source code
COPY src ./src

# Build the application
RUN mvn clean package -DskipTests

# Expose port
EXPOSE 8004

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8004/payments/health || exit 1

# Run the application
CMD ["java", "-jar", "target/payment-process-service-1.0.0.jar"]