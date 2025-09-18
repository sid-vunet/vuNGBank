package com.vubank.payment.service;

import co.elastic.apm.api.ElasticApm;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.vubank.payment.model.PaymentRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.client.ResourceAccessException;

import java.time.OffsetDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.CompletableFuture;

@Service
public class CoreBankingService {

    private static final Logger logger = LoggerFactory.getLogger(CoreBankingService.class);

    @Value("${corebanking.service.url}")
    private String coreBankingUrl;

    @Value("${corebanking.service.timeout:5000}")
    private int timeout;

    @Value("${corebanking.service.shared-secret}")
    private String sharedSecret;

    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;

    public CoreBankingService(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
        this.objectMapper = new ObjectMapper();
        this.objectMapper.registerModule(new JavaTimeModule());
    }

    public CompletableFuture<CoreBankingResponse> processPayment(String txnRef, PaymentRequest request, String userAuthorization) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                // Create canonical JSON payload
                Map<String, Object> payload = createCanonicalJson(txnRef, request);
                
                // Setup headers
                HttpHeaders headers = new HttpHeaders();
                headers.setContentType(MediaType.APPLICATION_JSON);
                headers.set("X-Request-Id", request.getXRequestId());
                headers.set("X-Origin-Service", "payment-process");
                headers.set("X-Txn-Ref", txnRef);
                
                // Add APM trace headers for distributed tracing
                co.elastic.apm.api.Transaction currentTransaction = ElasticApm.currentTransaction();
                if (currentTransaction != null) {
                    String traceParent = currentTransaction.getTraceId();
                    String traceState = currentTransaction.getId(); 
                    if (traceParent != null && !traceParent.isEmpty()) {
                        // Format traceparent header according to W3C spec
                        String formattedTraceParent = String.format("00-%s-%s-01", traceParent, traceState);
                        headers.set("traceparent", formattedTraceParent);
                        logger.debug("Added traceparent header: {}", formattedTraceParent);
                    }
                }
                
                // Use user's JWT token if provided, otherwise fallback to shared secret
                if (userAuthorization != null && !userAuthorization.trim().isEmpty()) {
                    headers.set("Authorization", userAuthorization);
                    logger.debug("Using user JWT token for CoreBanking authentication");
                } else {
                    headers.set("Authorization", "Bearer " + sharedSecret);
                    logger.debug("Using shared secret for CoreBanking authentication");
                }

                HttpEntity<Map<String, Object>> requestEntity = new HttpEntity<>(payload, headers);

                // Make the call to CoreBanking service
                String url = coreBankingUrl + "/core/payments";
                logger.info("Calling CoreBanking service for txnRef: {} at URL: {}", txnRef, url);

                ResponseEntity<Map> response = restTemplate.exchange(
                    url, HttpMethod.POST, requestEntity, Map.class);

                Map<String, Object> responseBody = response.getBody();
                if (responseBody == null) {
                    throw new RuntimeException("Empty response from CoreBanking service");
                }

                logger.info("Received response from CoreBanking for txnRef: {} with status: {}", 
                           txnRef, responseBody.get("status"));

                return mapToCoreBankingResponse(responseBody);

            } catch (ResourceAccessException e) {
                logger.error("Timeout calling CoreBanking service for txnRef: {}", txnRef, e);
                return new CoreBankingResponse("TIMEOUT", txnRef, null, null, "CoreBanking service timeout");
            } catch (Exception e) {
                logger.error("Error calling CoreBanking service for txnRef: {}", txnRef, e);
                return new CoreBankingResponse("REJECTED", txnRef, null, null, "Internal error: " + e.getMessage());
            }
        });
    }

    private Map<String, Object> createCanonicalJson(String txnRef, PaymentRequest request) {
        Map<String, Object> payload = new HashMap<>();
        payload.put("txnRef", txnRef);
        payload.put("paymentType", request.getPaymentType());
        payload.put("amount", request.getAmount());
        payload.put("currency", "INR");

        // Payer details
        Map<String, Object> payer = new HashMap<>();
        payer.put("name", request.getCustomerName());
        payer.put("accountNo", request.getFromAccountNo());
        payer.put("accountType", "SAVINGS"); // Default for demo
        payload.put("payer", payer);

        // Payee details
        Map<String, Object> payee = new HashMap<>();
        payee.put("name", request.getPayeeName());
        payee.put("accountNo", request.getToAccountNo());
        payee.put("ifsc", request.getIfscCode());
        payload.put("payee", payee);

        // Meta information
        Map<String, Object> meta = new HashMap<>();
        meta.put("branchName", request.getBranchName());
        meta.put("initiatedAt", request.getInitiatedAt().toString());
        meta.put("comments", request.getComments());
        payload.put("meta", meta);

        // Headers echo
        Map<String, Object> headersEcho = new HashMap<>();
        headersEcho.put("xRequestId", request.getXRequestId());
        headersEcho.put("xApiClient", request.getXApiClient());
        payload.put("headers", headersEcho);

        return payload;
    }

    private CoreBankingResponse mapToCoreBankingResponse(Map<String, Object> responseBody) {
        String status = (String) responseBody.get("status");
        String txnRef = (String) responseBody.get("txnRef");
        String cbsId = (String) responseBody.get("cbsId");
        String approvedAtStr = (String) responseBody.get("approvedAt");
        String reason = (String) responseBody.get("reason");

        OffsetDateTime approvedAt = null;
        if (approvedAtStr != null && !approvedAtStr.isEmpty()) {
            try {
                approvedAt = OffsetDateTime.parse(approvedAtStr);
            } catch (Exception e) {
                logger.warn("Could not parse approvedAt timestamp: {}", approvedAtStr, e);
            }
        }

        return new CoreBankingResponse(status, txnRef, cbsId, approvedAt, reason);
    }

    public static class CoreBankingResponse {
        private final String status;
        private final String txnRef;
        private final String cbsId;
        private final OffsetDateTime approvedAt;
        private final String reason;

        public CoreBankingResponse(String status, String txnRef, String cbsId, 
                                 OffsetDateTime approvedAt, String reason) {
            this.status = status;
            this.txnRef = txnRef;
            this.cbsId = cbsId;
            this.approvedAt = approvedAt;
            this.reason = reason;
        }

        public String getStatus() { return status; }
        public String getTxnRef() { return txnRef; }
        public String getCbsId() { return cbsId; }
        public OffsetDateTime getApprovedAt() { return approvedAt; }
        public String getReason() { return reason; }
    }
}