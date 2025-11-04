# Multi-stage build
# Stage 1: Build the application
FROM maven:3.9-eclipse-temurin-11 AS build

WORKDIR /app

# Copy pom.xml first to leverage Docker cache
COPY pom.xml .

# Download dependencies
RUN mvn dependency:go-offline -B

# Copy source code
COPY src ./src

# Build the application
RUN mvn clean package -DskipTests

# Stage 2: Runtime
FROM eclipse-temurin:11-jre-jammy

WORKDIR /app

# Install curl for health checks and download APM agent
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Copy the JAR file from the build stage
COPY --from=build /app/target/pdf-receipt-service-1.0.0.jar app.jar

# Download Elastic APM agent
RUN curl -o elastic-apm-agent.jar -L "https://oss.sonatype.org/service/local/artifact/maven/redirect?r=releases&g=co.elastic.apm&a=elastic-apm-agent&v=LATEST"

# Expose the port
EXPOSE 8003

# Run the application with APM agent
ENTRYPOINT ["java", "-javaagent:elastic-apm-agent.jar", "-jar", "app.jar"]