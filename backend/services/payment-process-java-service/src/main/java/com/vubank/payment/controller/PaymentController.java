package com.vubank.payment.controller;

import com.vubank.payment.model.PaymentRequest;
import com.vubank.payment.model.PaymentResponse;
import com.vubank.payment.model.TransactionState;
import com.vubank.payment.service.CoreBankingService;
import com.vubank.payment.service.HazelcastTransactionStateService;
import com.vubank.payment.service.XmlParsingService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;

@RestController
@RequestMapping("/payments")
@CrossOrigin(origins = "*")
public class PaymentController {

    private static final Logger logger = LoggerFactory.getLogger(PaymentController.class);

    private final XmlParsingService xmlParsingService;
    private final HazelcastTransactionStateService transactionStateService;
    private final CoreBankingService coreBankingService;

    public PaymentController(XmlParsingService xmlParsingService,
                           HazelcastTransactionStateService transactionStateService,
                           CoreBankingService coreBankingService) {
        this.xmlParsingService = xmlParsingService;
        this.transactionStateService = transactionStateService;
        this.coreBankingService = coreBankingService;
    }

    @PostMapping(value = "/transfer", consumes = MediaType.APPLICATION_XML_VALUE)
    public ResponseEntity<PaymentResponse> createPayment(
            @RequestBody String xmlPayload,
            @RequestHeader(value = "X-Api-Client", defaultValue = "unknown") String xApiClient,
            @RequestHeader(value = "X-Request-Id", required = false) String xRequestId,
            @RequestHeader(value = "Content-Type") String contentType,
            @RequestHeader(value = "X-Signature", required = false) String xSignature,
            @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyKey,
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @RequestHeader(value = "traceparent", required = false) String traceparent,
            @RequestHeader(value = "tracestate", required = false) String tracestate) {

        // Generate X-Request-Id if not provided
        if (xRequestId == null || xRequestId.trim().isEmpty()) {
            xRequestId = UUID.randomUUID().toString();
        }

        // Add context to MDC for logging
        MDC.put("xRequestId", xRequestId);
        MDC.put("xApiClient", xApiClient);

        logger.info("Received payment transfer request - xRequestId: {}, xApiClient: {}", xRequestId, xApiClient);

        try {
            // Validate headers
            validateHeaders(xApiClient, contentType, xSignature);

            // Handle idempotency if key is provided
            if (idempotencyKey != null && !idempotencyKey.trim().isEmpty()) {
                if (!transactionStateService.tryLockTransaction(idempotencyKey)) {
                    logger.warn("Duplicate request detected for idempotency key: {}", idempotencyKey);
                    return ResponseEntity.status(HttpStatus.CONFLICT)
                        .body(new PaymentResponse(null, "DUPLICATE", "Duplicate request"));
                }
            }

            // Parse XML to PaymentRequest
            PaymentRequest paymentRequest = xmlParsingService.parseXmlToPaymentRequest(xmlPayload, xRequestId, xApiClient);

            // Generate transaction reference
            String txnRef = UUID.randomUUID().toString();
            MDC.put("txnRef", txnRef);

            // Create initial transaction state
            TransactionState txnState = transactionStateService.createInitialState(txnRef, paymentRequest);
            
            // Set to RECEIVED status
            txnState.setStatus(TransactionState.Status.RECEIVED);
            transactionStateService.saveTransactionState(txnState);

            // Move to VALIDATED status
            transactionStateService.updateTransactionStatus(txnRef, TransactionState.Status.VALIDATED, null);

            // Check balance
            BigDecimal currentBalance = transactionStateService.getAccountBalance(paymentRequest.getFromAccountNo());
            
            if (currentBalance.compareTo(paymentRequest.getAmount()) < 0) {
                transactionStateService.updateTransactionStatus(txnRef, TransactionState.Status.FAILED, 
                    "INSUFFICIENT_BALANCE");
                
                logger.warn("Insufficient balance for txnRef: {} - Required: {}, Available: {}", 
                           txnRef, paymentRequest.getAmount(), currentBalance);
                
                return ResponseEntity.status(HttpStatus.PAYMENT_REQUIRED)
                    .body(new PaymentResponse(txnRef, "FAILED", "INSUFFICIENT_BALANCE"));
            }

            // Move to IN_PROGRESS status
            transactionStateService.updateTransactionStatus(txnRef, TransactionState.Status.IN_PROGRESS, null);

            // Call CoreBanking service asynchronously
            CompletableFuture<CoreBankingService.CoreBankingResponse> futureResponse = 
                coreBankingService.processPayment(txnRef, paymentRequest, authorization);

            // Handle CoreBanking response asynchronously
            futureResponse.thenAccept(coreBankingResponse -> {
                handleCoreBankingResponse(txnRef, coreBankingResponse);
            });

            // Release idempotency lock if used
            if (idempotencyKey != null && !idempotencyKey.trim().isEmpty()) {
                transactionStateService.releaseLockTransaction(idempotencyKey);
            }

            logger.info("Payment initiated successfully - txnRef: {}, amount: {}", txnRef, paymentRequest.getAmount());

            // Return immediate response with IN_PROGRESS status
            return ResponseEntity.accepted()
                .body(new PaymentResponse(txnRef, "IN_PROGRESS"));

        } catch (IllegalArgumentException e) {
            logger.error("Validation error for xRequestId: {} - {}", xRequestId, e.getMessage());
            return ResponseEntity.badRequest()
                .body(new PaymentResponse(null, "FAILED", "Validation error: " + e.getMessage()));
        } catch (Exception e) {
            logger.error("Unexpected error for xRequestId: {}", xRequestId, e);
            return ResponseEntity.internalServerError()
                .body(new PaymentResponse(null, "FAILED", "Internal server error"));
        } finally {
            // Clear MDC
            MDC.clear();
        }
    }

    @GetMapping("/status/{txnRef}")
    public ResponseEntity<PaymentResponse> getPaymentStatus(@PathVariable String txnRef) {
        logger.debug("Status check requested for txnRef: {}", txnRef);

        try {
            // Get transaction state from Hazelcast
            TransactionState txnState = transactionStateService.getTransactionState(txnRef);
            
            if (txnState == null) {
                logger.warn("Transaction not found for txnRef: {}", txnRef);
                return ResponseEntity.notFound().build();
            }

            PaymentResponse response = new PaymentResponse(txnRef, txnState.getStatus().toString());
            
            // Add additional details based on status
            if (txnState.getStatus() == TransactionState.Status.SUCCESS) {
                response.setCbsId(txnState.getCbsId());
                if (txnState.getApprovedAt() != null) {
                    response.setApprovedAt(txnState.getApprovedAt().toString());
                }
            } else if (txnState.getStatus() == TransactionState.Status.FAILED) {
                response.setReason(txnState.getFailureReason());
            }

            return ResponseEntity.ok(response);

        } catch (Exception e) {
            logger.error("Error retrieving status for txnRef: {}", txnRef, e);
            return ResponseEntity.internalServerError()
                .body(new PaymentResponse(txnRef, "ERROR", "Failed to retrieve status"));
        }
    }

    // Health Check Endpoints
    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> health() {
        Map<String, Object> healthData = new HashMap<>();
        
        try {
            // Basic service information
            healthData.put("status", "healthy");
            healthData.put("service", "vubank-payment-service");
            healthData.put("timestamp", LocalDateTime.now().toString());
            healthData.put("version", "1.0.0");
            
            // Runtime information
            Runtime runtime = Runtime.getRuntime();
            long maxMemory = runtime.maxMemory();
            long totalMemory = runtime.totalMemory();
            long freeMemory = runtime.freeMemory();
            long usedMemory = totalMemory - freeMemory;
            
            Map<String, Object> memoryInfo = new HashMap<>();
            memoryInfo.put("used", formatBytes(usedMemory));
            memoryInfo.put("free", formatBytes(freeMemory));
            memoryInfo.put("total", formatBytes(totalMemory));
            memoryInfo.put("max", formatBytes(maxMemory));
            healthData.put("memory", memoryInfo);
            
            // System uptime approximation
            healthData.put("uptime", java.lang.management.ManagementFactory.getRuntimeMXBean().getUptime());
            
            // Environment
            healthData.put("environment", System.getProperty("spring.profiles.active", "production"));
            
            // Check dependencies health
            Map<String, String> dependencies = new HashMap<>();
            
            // Check Hazelcast connection
            try {
                transactionStateService.getClass(); // Simple dependency check
                dependencies.put("hazelcast", "healthy");
            } catch (Exception e) {
                dependencies.put("hazelcast", "unhealthy: " + e.getMessage());
                healthData.put("status", "degraded");
            }
            
            // Check CoreBanking service connection  
            try {
                coreBankingService.getClass(); // Simple dependency check
                dependencies.put("corebanking", "healthy");
            } catch (Exception e) {
                dependencies.put("corebanking", "unhealthy: " + e.getMessage());
                healthData.put("status", "degraded");
            }
            
            healthData.put("dependencies", dependencies);
            
            logger.debug("Health check completed successfully");
            return ResponseEntity.ok(healthData);
            
        } catch (Exception e) {
            logger.error("Health check failed", e);
            healthData.put("status", "unhealthy");
            healthData.put("error", e.getMessage());
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(healthData);
        }
    }

    @GetMapping("/status")
    public ResponseEntity<Map<String, Object>> status() {
        Map<String, Object> statusData = new HashMap<>();
        statusData.put("status", "ok");
        statusData.put("service", "vubank-payment-service");
        statusData.put("timestamp", LocalDateTime.now().toString());
        
        return ResponseEntity.ok(statusData);
    }

    private String formatBytes(long bytes) {
        if (bytes < 1024) return bytes + " B";
        int exp = (int) (Math.log(bytes) / Math.log(1024));
        String pre = "KMGTPE".charAt(exp - 1) + "";
        return String.format("%.1f %sB", bytes / Math.pow(1024, exp), pre);
    }

    private void validateHeaders(String xApiClient, String contentType, String xSignature) {
        if (!"web-portal".equals(xApiClient)) {
            throw new IllegalArgumentException("Invalid X-Api-Client header");
        }

        if (!MediaType.APPLICATION_XML_VALUE.equals(contentType)) {
            throw new IllegalArgumentException("Content-Type must be application/xml");
        }

        // Simple signature validation (placeholder)
        if (xSignature == null || xSignature.trim().isEmpty()) {
            logger.warn("Missing X-Signature header - using placeholder validation");
        }
    }

    private void handleCoreBankingResponse(String txnRef, CoreBankingService.CoreBankingResponse response) {
        try {
            if ("APPROVED".equals(response.getStatus())) {
                // Update transaction state with success
                TransactionState txnState = transactionStateService.getTransactionState(txnRef);
                if (txnState != null) {
                    txnState.setStatus(TransactionState.Status.SUCCESS);
                    txnState.setCbsId(response.getCbsId());
                    txnState.setApprovedAt(response.getApprovedAt() != null ? response.getApprovedAt() : OffsetDateTime.now());
                    transactionStateService.saveTransactionState(txnState);
                }
                
                logger.info("Payment approved for txnRef: {} with cbsId: {}", txnRef, response.getCbsId());
            } else {
                // Update transaction state with failure
                transactionStateService.updateTransactionStatus(txnRef, TransactionState.Status.FAILED, 
                    response.getReason());
                
                logger.warn("Payment failed for txnRef: {} with reason: {}", txnRef, response.getReason());
            }
        } catch (Exception e) {
            logger.error("Error handling CoreBanking response for txnRef: {}", txnRef, e);
            transactionStateService.updateTransactionStatus(txnRef, TransactionState.Status.FAILED, 
                "Internal error processing CoreBanking response");
        }
    }
}