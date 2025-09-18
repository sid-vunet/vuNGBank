package com.vubank.core.service;

import co.elastic.apm.api.ElasticApm;
import co.elastic.apm.api.Span;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;

@Service
public class AccountsService {

    private static final Logger logger = LoggerFactory.getLogger(AccountsService.class);

    @Value("${accounts.service.url:http://accounts-go-service:8002}")
    private String accountsServiceUrl;

    @Value("${accounts.service.jwt.secret:your-super-secret-jwt-key}")
    private String jwtSecret;

    private final RestTemplate restTemplate;

    public AccountsService(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }

    /**
     * Update account balance by debiting the specified amount
     */
    public boolean debitAccount(String accountNumber, BigDecimal amount, String referenceNumber, String description) {
        Span span = ElasticApm.currentSpan().startSpan("accounts", "http", "debit-account");
        span.addLabel("account-number", accountNumber);
        span.addLabel("amount", amount.toString());
        span.addLabel("reference-number", referenceNumber);
        
        try {
            // Create request payload
            Map<String, Object> request = new HashMap<>();
            request.put("accountNumber", accountNumber);
            request.put("amount", amount.negate().doubleValue()); // Negative for debit
            request.put("transactionType", "DEBIT");
            request.put("referenceNumber", referenceNumber);
            request.put("description", description);

            // Create headers with JWT token
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.setBearerAuth(jwtSecret);

            HttpEntity<Map<String, Object>> entity = new HttpEntity<>(request, headers);

            // Make API call
            String url = accountsServiceUrl + "/internal/accounts/update-balance";
            logger.info("Calling accounts service to debit account {} with amount {}: {}", 
                       accountNumber, amount, url);

            ResponseEntity<Map> response = restTemplate.exchange(
                url, 
                HttpMethod.POST, 
                entity, 
                Map.class
            );

            if (response.getStatusCode() == HttpStatus.OK) {
                Map<String, Object> responseBody = response.getBody();
                Boolean success = (Boolean) responseBody.get("success");
                
                if (Boolean.TRUE.equals(success)) {
                    span.addLabel("result", "success");
                    Double oldBalance = (Double) responseBody.get("oldBalance");
                    Double newBalance = (Double) responseBody.get("newBalance");
                    Integer transactionId = (Integer) responseBody.get("transactionId");
                    
                    logger.info("Successfully debited account {}: {} -> {} (txnId: {})", 
                               accountNumber, oldBalance, newBalance, transactionId);
                    return true;
                } else {
                    span.addLabel("result", "business-error");
                    String message = (String) responseBody.get("message");
                    logger.warn("Failed to debit account {}: {}", accountNumber, message);
                    return false;
                }
            } else {
                span.addLabel("result", "http-error");
                logger.error("Accounts service returned status {}", response.getStatusCode());
                return false;
            }

        } catch (Exception e) {
            span.addLabel("result", "exception");
            logger.error("Error calling accounts service to debit account {}", accountNumber, e);
            ElasticApm.captureException(e);
            return false;
        } finally {
            span.end();
        }
    }

    /**
     * Update account balance by crediting the specified amount (for future use)
     */
    public boolean creditAccount(String accountNumber, BigDecimal amount, String referenceNumber, String description) {
        Span span = ElasticApm.currentSpan().startSpan("accounts", "http", "credit-account");
        span.addLabel("account-number", accountNumber);
        span.addLabel("amount", amount.toString());
        span.addLabel("reference-number", referenceNumber);
        
        try {
            // Create request payload
            Map<String, Object> request = new HashMap<>();
            request.put("accountNumber", accountNumber);
            request.put("amount", amount.doubleValue()); // Positive for credit
            request.put("transactionType", "CREDIT");
            request.put("referenceNumber", referenceNumber);
            request.put("description", description);

            // Create headers with JWT token
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.setBearerAuth(jwtSecret);

            HttpEntity<Map<String, Object>> entity = new HttpEntity<>(request, headers);

            // Make API call
            String url = accountsServiceUrl + "/internal/accounts/update-balance";
            logger.info("Calling accounts service to credit account {} with amount {}: {}", 
                       accountNumber, amount, url);

            ResponseEntity<Map> response = restTemplate.exchange(
                url, 
                HttpMethod.POST, 
                entity, 
                Map.class
            );

            if (response.getStatusCode() == HttpStatus.OK) {
                Map<String, Object> responseBody = response.getBody();
                Boolean success = (Boolean) responseBody.get("success");
                
                if (Boolean.TRUE.equals(success)) {
                    span.addLabel("result", "success");
                    Double oldBalance = (Double) responseBody.get("oldBalance");
                    Double newBalance = (Double) responseBody.get("newBalance");
                    Integer transactionId = (Integer) responseBody.get("transactionId");
                    
                    logger.info("Successfully credited account {}: {} -> {} (txnId: {})", 
                               accountNumber, oldBalance, newBalance, transactionId);
                    return true;
                } else {
                    span.addLabel("result", "business-error");
                    String message = (String) responseBody.get("message");
                    logger.warn("Failed to credit account {}: {}", accountNumber, message);
                    return false;
                }
            } else {
                span.addLabel("result", "http-error");
                logger.error("Accounts service returned status {}", response.getStatusCode());
                return false;
            }

        } catch (Exception e) {
            span.addLabel("result", "exception");
            logger.error("Error calling accounts service to credit account {}", accountNumber, e);
            ElasticApm.captureException(e);
            return false;
        } finally {
            span.end();
        }
    }
}