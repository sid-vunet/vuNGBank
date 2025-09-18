package com.vubank.payment.controller;

import co.elastic.apm.api.ElasticApm;
import co.elastic.apm.api.Span;
import co.elastic.apm.api.Transaction;
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
import java.time.OffsetDateTime;
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
            @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyKey) {

        // Start APM Transaction
        Transaction transaction = ElasticApm.startTransaction();
        transaction.setName("payment-transfer");
        transaction.setType("request");

        // Generate X-Request-Id if not provided
        if (xRequestId == null || xRequestId.trim().isEmpty()) {
            xRequestId = UUID.randomUUID().toString();
        }

        // Add context to MDC for logging
        MDC.put("xRequestId", xRequestId);
        MDC.put("xApiClient", xApiClient);

        // Add labels to APM transaction
        transaction.addLabel("x-request-id", xRequestId);
        transaction.addLabel("x-api-client", xApiClient);
        transaction.addLabel("payment-service", "hazelcast-payment-processor");

        logger.info("Received payment transfer request - xRequestId: {}, xApiClient: {}", xRequestId, xApiClient);

        try {
            // Span for header validation
            Span validationSpan = transaction.startSpan("payment", "validation", "header-validation");
            try {
                validateHeaders(xApiClient, contentType, xSignature);
                validationSpan.addLabel("validation-result", "success");
            } finally {
                validationSpan.end();
            }

            // Handle idempotency if key is provided
            if (idempotencyKey != null && !idempotencyKey.trim().isEmpty()) {
                Span idempotencySpan = transaction.startSpan("payment", "idempotency", "lock-check");
                try {
                    if (!transactionStateService.tryLockTransaction(idempotencyKey)) {
                        logger.warn("Duplicate request detected for idempotency key: {}", idempotencyKey);
                        idempotencySpan.addLabel("duplicate-detected", "true");
                        transaction.addLabel("result", "duplicate");
                        return ResponseEntity.status(HttpStatus.CONFLICT)
                            .body(new PaymentResponse(null, "DUPLICATE", "Duplicate request"));
                    }
                    idempotencySpan.addLabel("lock-acquired", "true");
                } finally {
                    idempotencySpan.end();
                }
            }

            // Span for XML parsing
            Span xmlParsingSpan = transaction.startSpan("payment", "parsing", "xml-to-payment-request");
            PaymentRequest paymentRequest;
            try {
                paymentRequest = xmlParsingService.parseXmlToPaymentRequest(xmlPayload, xRequestId, xApiClient);
                xmlParsingSpan.addLabel("amount", paymentRequest.getAmount().toString());
                xmlParsingSpan.addLabel("from-account", paymentRequest.getFromAccountNo());
                xmlParsingSpan.addLabel("to-account", paymentRequest.getToAccountNo());
            } finally {
                xmlParsingSpan.end();
            }

            // Generate transaction reference
            String txnRef = UUID.randomUUID().toString();
            transaction.addLabel("txn-ref", txnRef);
            MDC.put("txnRef", txnRef);

            // Span for Hazelcast state management
            Span hazelcastSpan = transaction.startSpan("payment", "hazelcast", "transaction-state-management");
            try {
                // Create initial transaction state
                TransactionState txnState = transactionStateService.createInitialState(txnRef, paymentRequest);
                
                // Set to RECEIVED status
                txnState.setStatus(TransactionState.Status.RECEIVED);
                transactionStateService.saveTransactionState(txnState);

                // Move to VALIDATED status
                transactionStateService.updateTransactionStatus(txnRef, TransactionState.Status.VALIDATED, null);

                hazelcastSpan.addLabel("initial-status", "received");
                hazelcastSpan.addLabel("validated-status", "validated");
            } finally {
                hazelcastSpan.end();
            }

            // Span for balance check
            Span balanceSpan = transaction.startSpan("payment", "validation", "balance-check");
            try {
                BigDecimal currentBalance = transactionStateService.getAccountBalance(paymentRequest.getFromAccountNo());
                balanceSpan.addLabel("current-balance", currentBalance.toString());
                balanceSpan.addLabel("required-amount", paymentRequest.getAmount().toString());
                
                if (currentBalance.compareTo(paymentRequest.getAmount()) < 0) {
                    transactionStateService.updateTransactionStatus(txnRef, TransactionState.Status.FAILED, 
                        "INSUFFICIENT_BALANCE");
                    
                    logger.warn("Insufficient balance for txnRef: {} - Required: {}, Available: {}", 
                               txnRef, paymentRequest.getAmount(), currentBalance);
                    
                    balanceSpan.addLabel("balance-check-result", "insufficient");
                    transaction.addLabel("result", "insufficient-balance");
                    
                    return ResponseEntity.status(HttpStatus.PAYMENT_REQUIRED)
                        .body(new PaymentResponse(txnRef, "FAILED", "INSUFFICIENT_BALANCE"));
                }
                balanceSpan.addLabel("balance-check-result", "sufficient");
            } finally {
                balanceSpan.end();
            }

            // Move to IN_PROGRESS status
            transactionStateService.updateTransactionStatus(txnRef, TransactionState.Status.IN_PROGRESS, null);

            // Call CoreBanking service asynchronously with APM context propagation
            CompletableFuture<CoreBankingService.CoreBankingResponse> futureResponse = 
                coreBankingService.processPayment(txnRef, paymentRequest);

            // Handle CoreBanking response asynchronously with APM context
            futureResponse.thenAccept(coreBankingResponse -> {
                // Propagate APM context to async callback
                Span asyncSpan = ElasticApm.currentSpan().startSpan("payment", "callback", "corebanking-response");
                asyncSpan.addLabel("txn-ref", txnRef);
                try {
                    handleCoreBankingResponse(txnRef, coreBankingResponse);
                    asyncSpan.addLabel("corebanking-status", coreBankingResponse.getStatus());
                } finally {
                    asyncSpan.end();
                }
            });

            // Release idempotency lock if used
            if (idempotencyKey != null && !idempotencyKey.trim().isEmpty()) {
                transactionStateService.releaseLockTransaction(idempotencyKey);
            }

            logger.info("Payment initiated successfully - txnRef: {}, amount: {}", txnRef, paymentRequest.getAmount());

            transaction.addLabel("result", "accepted");
            transaction.addLabel("amount", paymentRequest.getAmount().toString());

            // Return immediate response with IN_PROGRESS status
            return ResponseEntity.accepted()
                .body(new PaymentResponse(txnRef, "IN_PROGRESS"));

        } catch (IllegalArgumentException e) {
            logger.error("Validation error for xRequestId: {} - {}", xRequestId, e.getMessage());
            transaction.addLabel("result", "validation-error");
            transaction.addLabel("error-type", "validation");
            ElasticApm.captureException(e);
            return ResponseEntity.badRequest()
                .body(new PaymentResponse(null, "FAILED", "Validation error: " + e.getMessage()));
        } catch (Exception e) {
            logger.error("Unexpected error for xRequestId: {}", xRequestId, e);
            transaction.addLabel("result", "internal-error");
            transaction.addLabel("error-type", "unexpected");
            ElasticApm.captureException(e);
            return ResponseEntity.internalServerError()
                .body(new PaymentResponse(null, "FAILED", "Internal server error"));
        } finally {
            transaction.end();
            // Clear MDC
            MDC.clear();
        }
    }

    @GetMapping("/status/{txnRef}")
    public ResponseEntity<PaymentResponse> getPaymentStatus(@PathVariable String txnRef) {
        // Start APM Transaction for status check
        Transaction transaction = ElasticApm.startTransaction();
        transaction.setName("payment-status-check");
        transaction.setType("request");
        transaction.addLabel("txn-ref", txnRef);
        transaction.addLabel("operation", "status-query");

        logger.debug("Status check requested for txnRef: {}", txnRef);

        try {
            // Span for Hazelcast state retrieval
            Span hazelcastSpan = transaction.startSpan("payment", "hazelcast", "transaction-state-retrieval");
            TransactionState txnState;
            try {
                txnState = transactionStateService.getTransactionState(txnRef);
                hazelcastSpan.addLabel("state-found", txnState != null ? "true" : "false");
            } finally {
                hazelcastSpan.end();
            }
            
            if (txnState == null) {
                logger.warn("Transaction not found for txnRef: {}", txnRef);
                transaction.addLabel("result", "not-found");
                return ResponseEntity.notFound().build();
            }

            PaymentResponse response = new PaymentResponse(txnRef, txnState.getStatus().toString());
            transaction.addLabel("status", txnState.getStatus().toString());
            
            // Add additional details based on status
            if (txnState.getStatus() == TransactionState.Status.SUCCESS) {
                response.setCbsId(txnState.getCbsId());
                if (txnState.getApprovedAt() != null) {
                    response.setApprovedAt(txnState.getApprovedAt().toString());
                }
                transaction.addLabel("cbs-id", txnState.getCbsId());
                transaction.addLabel("result", "success");
            } else if (txnState.getStatus() == TransactionState.Status.FAILED) {
                response.setReason(txnState.getFailureReason());
                transaction.addLabel("failure-reason", txnState.getFailureReason());
                transaction.addLabel("result", "failed");
            } else {
                transaction.addLabel("result", "in-progress");
            }

            return ResponseEntity.ok(response);

        } catch (Exception e) {
            logger.error("Error retrieving status for txnRef: {}", txnRef, e);
            transaction.addLabel("result", "error");
            transaction.addLabel("error-type", "status-retrieval");
            ElasticApm.captureException(e);
            return ResponseEntity.internalServerError()
                .body(new PaymentResponse(txnRef, "ERROR", "Failed to retrieve status"));
        } finally {
            transaction.end();
        }
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