package com.vubank.core.controller;

import com.vubank.core.service.PaymentProcessingService;
import io.jsonwebtoken.Jwts;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.CompletableFuture;

@RestController
@RequestMapping("/core")
@CrossOrigin(origins = "*")
public class CoreBankingController {

    private static final Logger logger = LoggerFactory.getLogger(CoreBankingController.class);

    @Value("${security.shared-secret}")
    private String sharedSecret;

    private final PaymentProcessingService paymentProcessingService;

    public CoreBankingController(PaymentProcessingService paymentProcessingService) {
        this.paymentProcessingService = paymentProcessingService;
    }

    @PostMapping(value = "/payments", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<Map<String, Object>> processPayment(
            @RequestBody Map<String, Object> paymentRequest,
            @RequestHeader(value = "X-Request-Id") String xRequestId,
            @RequestHeader(value = "X-Origin-Service") String xOriginService,
            @RequestHeader(value = "X-Txn-Ref") String xTxnRef,
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @RequestHeader(value = "traceparent", required = false) String traceparent,
            @RequestHeader(value = "tracestate", required = false) String tracestate) {

        // Add context to MDC for logging
        MDC.put("xRequestId", xRequestId);
        MDC.put("xTxnRef", xTxnRef);
        MDC.put("xOriginService", xOriginService);

        logger.info("Received payment processing request - xRequestId: {}, xTxnRef: {}, origin: {}", 
                   xRequestId, xTxnRef, xOriginService);

        try {
            // Authorization check
            if (!isAuthorized(authorization)) {
                logger.warn("Unauthorized payment processing request for xRequestId: {}", xRequestId);
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(createErrorResponse(xTxnRef, "UNAUTHORIZED", "Invalid authorization"));
            }

            // Header validation
            if (!"payment-process".equals(xOriginService)) {
                logger.warn("Invalid origin service: {} for xRequestId: {}", xOriginService, xRequestId);
                return ResponseEntity.badRequest()
                    .body(createErrorResponse(xTxnRef, "INVALID_ORIGIN", "Invalid origin service"));
            }

            // Process payment synchronously (as per the 1.5s simulation requirement)
            CompletableFuture<PaymentProcessingService.ProcessingResult> futureResult = 
                paymentProcessingService.processPayment(paymentRequest, authorization);

            PaymentProcessingService.ProcessingResult result = futureResult.get();

            Map<String, Object> response = createSuccessResponse(result);
            
            logger.info("Payment processing completed for xRequestId: {} with status: {}", 
                       xRequestId, result.getStatus());

            return ResponseEntity.ok(response);

        } catch (Exception e) {
            logger.error("Error processing payment for xRequestId: {}", xRequestId, e);
            return ResponseEntity.internalServerError()
                .body(createErrorResponse(xTxnRef, "INTERNAL_ERROR", "Processing failed: " + e.getMessage()));
        } finally {
            // Clear MDC
            MDC.clear();
        }
    }

    @GetMapping("/payments/{cbsId}")
    public ResponseEntity<Map<String, Object>> getPaymentStatus(@PathVariable String cbsId) {
        logger.info("Payment status request for cbsId: {}", cbsId);
        
        // This is optional for ops/debug as mentioned in requirements
        Map<String, Object> response = new HashMap<>();
        response.put("cbsId", cbsId);
        response.put("status", "NOT_IMPLEMENTED");
        response.put("message", "Status lookup by cbsId not implemented yet");
        
        return ResponseEntity.ok(response);
    }

    private boolean isAuthorized(String authorization) {
        if (authorization == null || !authorization.startsWith("Bearer ")) {
            logger.debug("Authorization failed: missing or invalid Bearer token format");
            return false;
        }
        
        String token = authorization.substring("Bearer ".length());
        logger.debug("Received token for authorization: " + token.substring(0, Math.min(20, token.length())) + "...");
        
        // First check if it's the shared secret
        if (sharedSecret.equals(token)) {
            logger.debug("Authorization successful: shared secret match");
            return true;
        }
        
        // If not shared secret, validate as JWT token
        boolean jwtValid = isValidJwtToken(token);
        logger.debug("JWT validation result: " + jwtValid);
        return jwtValid;
    }
    
    private boolean isValidJwtToken(String token) {
        try {
            logger.debug("Attempting to validate JWT token: " + token.substring(0, Math.min(50, token.length())) + "...");
            // Use the same JWT secret as accounts service
            String jwtSecret = "vubank-super-secret-jwt-key-2023";
            io.jsonwebtoken.Jwts.parserBuilder()
                .setSigningKey(jwtSecret.getBytes(java.nio.charset.StandardCharsets.UTF_8))
                .build()
                .parseClaimsJws(token);
            logger.debug("JWT token validation successful");
            return true;
        } catch (Exception e) {
            logger.warn("JWT token validation failed: " + e.getMessage());
            return false;
        }
    }

    private Map<String, Object> createSuccessResponse(PaymentProcessingService.ProcessingResult result) {
        Map<String, Object> response = new HashMap<>();
        response.put("status", result.getStatus());
        response.put("txnRef", result.getTxnRef() != null ? result.getTxnRef().toString() : null);
        
        if ("APPROVED".equals(result.getStatus())) {
            response.put("cbsId", result.getCbsId() != null ? result.getCbsId().toString() : null);
            if (result.getApprovedAt() != null) {
                response.put("approvedAt", result.getApprovedAt().format(DateTimeFormatter.ISO_OFFSET_DATE_TIME));
            }
        } else if ("REJECTED".equals(result.getStatus())) {
            response.put("reason", result.getReason());
        }
        
        return response;
    }

    private Map<String, Object> createErrorResponse(String txnRef, String status, String reason) {
        Map<String, Object> response = new HashMap<>();
        response.put("status", status);
        response.put("txnRef", txnRef);
        response.put("reason", reason);
        return response;
    }
}