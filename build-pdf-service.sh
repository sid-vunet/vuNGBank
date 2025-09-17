#!/bin/bash

# Build PDF Receipt Java Service
echo "Building PDF Receipt Service..."

cd backend/services/pdf-receipt-java-service

# Check if Maven is installed
if ! command -v mvn &> /dev/null; then
    echo "Error: Maven is not installed. Please install Maven to build the PDF service."
    echo "You can install Maven using:"
    echo "  macOS: brew install maven"
    echo "  Ubuntu/Debian: sudo apt-get install maven"
    echo "  CentOS/RHEL: sudo yum install maven"
    exit 1
fi

# Clean and compile
echo "Compiling PDF service..."
mvn clean compile

# Package the application
echo "Packaging PDF service..."
mvn package -DskipTests

if [ $? -eq 0 ]; then
    echo "✅ PDF Receipt Service built successfully!"
    echo "JAR file location: target/pdf-receipt-service-1.0.0.jar"
    echo ""
    echo "To run the service:"
    echo "  mvn spring-boot:run"
    echo "  OR"
    echo "  java -jar target/pdf-receipt-service-1.0.0.jar"
    echo ""
    echo "Service will be available at: http://localhost:8003"
else
    echo "❌ Build failed!"
    exit 1
fi