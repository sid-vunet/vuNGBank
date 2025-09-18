package com.vubank.core.service;

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

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class AccountsService {

    private static final Logger logger = LoggerFactory.getLogger(AccountsService.class);

    @Value("${accounts.service.url:http://accounts-go-service:8002}")
    private String accountsServiceUrl;

    @Value("${accounts.service.jwt.secret:vubank-super-secret-jwt-key-2023}")
    private String jwtSecret;

    private final RestTemplate restTemplate;

    public AccountsService(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }

    /**
     * Generate a JWT token for internal service communication
     */
    private String generateServiceToken() {
        try {
            SecretKey key = Keys.hmacShaKeyFor(jwtSecret.getBytes(StandardCharsets.UTF_8));
            
            Map<String, Object> claims = new HashMap<>();
            claims.put("user_id", "corebanking-service");
            claims.put("roles", List.of("retail"));
            
            return Jwts.builder()
                .setClaims(claims)
                .setIssuedAt(new Date())
                .setExpiration(new Date(System.currentTimeMillis() + 3600000)) // 1 hour
                .signWith(key, SignatureAlgorithm.HS256)
                .compact();
        } catch (Exception e) {
            logger.error("Failed to generate JWT token", e);
            return null;
        }
    }

    /**
     * Update account balance by debiting the specified amount
     */
    public boolean debitAccount(String accountNumber, BigDecimal amount, String referenceNumber, String description, String userAuthorization) {
        try {
            // Create request payload
            Map<String, Object> request = new HashMap<>();
            request.put("accountNumber", accountNumber);
            request.put("amount", amount.negate().doubleValue()); // Negative for debit
            request.put("transactionType", "DEBIT");
            request.put("referenceNumber", referenceNumber);
            request.put("description", description);

            // Create headers with user's JWT token
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            
            if (userAuthorization != null && !userAuthorization.trim().isEmpty()) {
                headers.set("Authorization", userAuthorization);
                logger.debug("Using user JWT token for debit account call");
            } else {
                // Fallback to service token generation if no user token provided
                String jwtToken = generateServiceToken();
                if (jwtToken != null) {
                    headers.setBearerAuth(jwtToken);
                    logger.debug("Using generated JWT token for debit account call");
                } else {
                    logger.warn("Failed to generate JWT token for debit, using fallback secret");
                    headers.setBearerAuth(jwtSecret);
                }
            }

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
                    // Handle numeric types safely - they might come as different types from JSON
                    Number oldBalanceNum = (Number) responseBody.get("oldBalance");
                    Number newBalanceNum = (Number) responseBody.get("newBalance");
                    Number transactionIdNum = (Number) responseBody.get("transactionId");
                    
                    Double oldBalance = oldBalanceNum.doubleValue();
                    Double newBalance = newBalanceNum.doubleValue();
                    Integer transactionId = transactionIdNum.intValue();
                    
                    logger.info("Successfully debited account {}: {} -> {} (txnId: {})", 
                               accountNumber, oldBalance, newBalance, transactionId);
                    
                    // Now call recordTransaction to log this in user's transaction history
                    try {
                        String transactionType = amount.compareTo(BigDecimal.ZERO) < 0 ? "debit" : "credit";
                        BigDecimal transactionAmount = amount.abs();
                        BigDecimal balanceAfter = BigDecimal.valueOf(newBalance);
                        
                        recordTransaction(accountNumber, transactionType, 
                                       transactionAmount, description, referenceNumber, balanceAfter, 
                                       "completed", userAuthorization);
                        logger.info("Successfully recorded transaction for account {}", accountNumber);
                    } catch (Exception e) {
                        logger.error("Failed to record transaction for account {} but balance was updated: {}", 
                                   accountNumber, e.getMessage());
                        // Don't fail the entire operation since balance was already updated
                    }
                    
                    return true;
                } else {
                    String message = (String) responseBody.get("message");
                    logger.warn("Failed to debit account {}: {}", accountNumber, message);
                    return false;
                }
            } else {
                logger.error("Accounts service returned status {}", response.getStatusCode());
                return false;
            }

        } catch (Exception e) {
            logger.error("Error calling accounts service to debit account {}", accountNumber, e);
            return false;
        }
    }

    /**
     * Update account balance by crediting the specified amount (for future use)
     */
    public boolean creditAccount(String accountNumber, BigDecimal amount, String referenceNumber, String description) {
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
                    // Handle numeric types safely - they might come as different types from JSON
                    Number oldBalanceNum = (Number) responseBody.get("oldBalance");
                    Number newBalanceNum = (Number) responseBody.get("newBalance");
                    Number transactionIdNum = (Number) responseBody.get("transactionId");
                    
                    Double oldBalance = oldBalanceNum.doubleValue();
                    Double newBalance = newBalanceNum.doubleValue();
                    Integer transactionId = transactionIdNum.intValue();
                    
                    logger.info("Successfully credited account {}: {} -> {} (txnId: {})", 
                               accountNumber, oldBalance, newBalance, transactionId);
                    return true;
                } else {
                    String message = (String) responseBody.get("message");
                    logger.warn("Failed to credit account {}: {}", accountNumber, message);
                    return false;
                }
            } else {
                logger.error("Accounts service returned status {}", response.getStatusCode());
                return false;
            }

        } catch (Exception e) {
            logger.error("Error calling accounts service to credit account {}", accountNumber, e);
            return false;
        }
    }

    /**
     * Record transaction in the accounts service
     */
    public boolean recordTransaction(String accountNumber, String transactionType, BigDecimal amount, 
                                   String description, String referenceNumber, BigDecimal balanceAfter, 
                                   String status, String userAuthorization) {
        try {
            // Create request payload
            Map<String, Object> request = new HashMap<>();
            request.put("accountNumber", accountNumber);
            request.put("transactionType", transactionType);
            request.put("amount", amount.doubleValue());
            request.put("description", description);
            request.put("referenceNumber", referenceNumber);
            request.put("balanceAfter", balanceAfter.doubleValue());
            request.put("status", status != null ? status : "completed");

            // Create headers with user's JWT token
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            
            if (userAuthorization != null && !userAuthorization.trim().isEmpty()) {
                headers.set("Authorization", userAuthorization);
                logger.debug("Using user JWT token for record transaction call");
            } else {
                // Fallback to service token generation if no user token provided
                String jwtToken = generateServiceToken();
                if (jwtToken != null) {
                    headers.setBearerAuth(jwtToken);
                    logger.debug("Using generated JWT token for record transaction call");
                } else {
                    logger.warn("Failed to generate JWT token for transaction recording, using fallback secret");
                    headers.setBearerAuth(jwtSecret);
                }
            }

            HttpEntity<Map<String, Object>> entity = new HttpEntity<>(request, headers);

            // Make API call
            String url = accountsServiceUrl + "/internal/accounts/create-transaction";
            logger.info("Calling accounts service to record transaction for account {} with amount {}: {}", 
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
                    // Handle numeric types safely - they might come as different types from JSON
                    Number transactionIdNum = (Number) responseBody.get("transactionId");
                    Integer transactionId = transactionIdNum != null ? transactionIdNum.intValue() : null;
                    String message = (String) responseBody.get("message");
                    
                    logger.info("Successfully recorded transaction for account {}: txnId={}, message={}", 
                               accountNumber, transactionId, message);
                    return true;
                } else {
                    String message = (String) responseBody.get("message");
                    logger.warn("Failed to record transaction for account {}: {}", accountNumber, message);
                    return false;
                }
            } else {
                logger.error("Accounts service returned status {} for transaction recording", response.getStatusCode());
                return false;
            }

        } catch (Exception e) {
            logger.error("Error calling accounts service to record transaction for account {}", accountNumber, e);
            return false;
        }
    }
}