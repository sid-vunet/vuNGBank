# VuBank PDF Receipt Service

A Java Spring Boot microservice for generating PDF transaction receipts for the VuBank banking platform.

## Features

- Generate PDF receipts for bank transactions
- Professional banking receipt format with VuBank branding
- RESTful API endpoints for receipt generation
- Automatic file naming with transaction ID and timestamp
- Cross-origin resource sharing (CORS) enabled for frontend integration

## Technology Stack

- **Java 11**
- **Spring Boot 2.7.14**
- **iText PDF 5.5.13** - PDF generation library
- **Maven** - Build and dependency management

## API Endpoints

### Generate Receipt
- **Endpoint**: `POST /api/pdf/generate-receipt`
- **Description**: Generates a PDF receipt for a transaction
- **Request Body**: TransactionReceipt JSON object
- **Response**: PDF file download

#### Request Example:
```json
{
    "transactionId": "TXN123456789",
    "fromAccount": "Savings - ****1234",
    "toAccount": "987654321",
    "payeeName": "John Smith",
    "amount": 1500.00,
    "paymentMode": "IMPS",
    "timestamp": "2024-01-15T10:30:00",
    "status": "SUCCESS",
    "customerName": "John Doe",
    "customerId": "CUST001"
}
```

### Health Check
- **Endpoint**: `GET /api/pdf/health`
- **Description**: Service health check
- **Response**: Service status message

## Building and Running

### Prerequisites
- Java 11 or higher
- Maven 3.6+

### Build
```bash
mvn clean compile
```

### Run
```bash
mvn spring-boot:run
```

### Package
```bash
mvn clean package
```

### Docker Build
```bash
docker build -t vubank-pdf-service .
```

### Docker Run
```bash
docker run -p 8003:8003 vubank-pdf-service
```

## Service Configuration

The service runs on port **8003** by default. This can be configured in `application.properties`:

```properties
server.port=8003
```

## Integration with Frontend

The frontend can call this service to generate and download PDF receipts:

```javascript
async function downloadReceipt(transactionData) {
    const response = await fetch('http://localhost:8003/api/pdf/generate-receipt', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(transactionData)
    });
    
    if (response.ok) {
        const blob = await response.blob();
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `VuBank_Receipt_${transactionData.transactionId}.pdf`;
        a.click();
        window.URL.revokeObjectURL(url);
    }
}
```

## PDF Receipt Format

The generated PDF includes:
- VuBank header and branding
- Transaction ID and timestamp
- Customer details
- Transaction details (from/to accounts, payee name)
- Payment mode and amount (highlighted)
- Professional footer with contact information

## Development

### Project Structure
```
src/
├── main/
│   ├── java/
│   │   └── com/vubank/pdf/
│   │       ├── PdfReceiptServiceApplication.java
│   │       ├── controller/
│   │       │   └── PdfReceiptController.java
│   │       ├── model/
│   │       │   └── TransactionReceipt.java
│   │       └── service/
│   │           └── PdfGeneratorService.java
│   └── resources/
│       └── application.properties
└── test/
```

### Dependencies
- Spring Boot Web Starter
- Spring Boot Actuator (for health checks)
- iText PDF (for PDF generation)
- Jackson (for JSON processing)

## Troubleshooting

### Common Issues

1. **Port already in use**: Change the port in `application.properties`
2. **PDF generation errors**: Check that all required fields are provided in the request
3. **CORS issues**: Ensure the frontend origin is included in the `@CrossOrigin` annotation

### Logs
Service logs are configured to show INFO level messages for the application and WARN level for Spring framework.

## Future Enhancements

- Add email functionality to send receipts
- Support for different receipt templates
- Integration with actual transaction database
- Enhanced error handling and validation
- Metrics and monitoring integration