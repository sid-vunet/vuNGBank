package com.vubank.core.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.vubank.core.model.CorePayment;
import com.vubank.core.repository.CorePaymentRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;

@Service
public class PaymentProcessingService {

    private static final Logger logger = LoggerFactory.getLogger(PaymentProcessingService.class);

    @Value("${processing.simulation.delay.ms:1500}")
    private long processingDelayMs;

    @Value("${processing.default.account.type:SAVINGS}")
    private String defaultAccountType;

    private final CorePaymentRepository corePaymentRepository;
    private final ObjectMapper objectMapper;
    private final AccountsService accountsService;

    public PaymentProcessingService(CorePaymentRepository corePaymentRepository, AccountsService accountsService) {
        this.corePaymentRepository = corePaymentRepository;
        this.accountsService = accountsService;
        this.objectMapper = new ObjectMapper();
        this.objectMapper.registerModule(new JavaTimeModule());
    }

    public CompletableFuture<ProcessingResult> processPayment(Map<String, Object> paymentRequest, String userAuthorization) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                // Extract and validate payment data
                PaymentData paymentData = extractPaymentData(paymentRequest);
                
                // Check for duplicate txnRef
                if (corePaymentRepository.existsByTxnRef(paymentData.getTxnRef())) {
                    logger.warn("Duplicate transaction detected for txnRef: {}", paymentData.getTxnRef());
                    return new ProcessingResult("REJECTED", paymentData.getTxnRef(), null, null, 
                        "Duplicate transaction reference");
                }

                // Create CorePayment entity
                CorePayment corePayment = createCorePayment(paymentData);
                
                // Store raw JSON
                try {
                    corePayment.setRawJson(objectMapper.writeValueAsString(paymentRequest));
                } catch (JsonProcessingException e) {
                    logger.warn("Failed to serialize raw JSON for txnRef: {}", paymentData.getTxnRef(), e);
                }

                // Save initial state
                corePayment.setStatus("PROCESSING");
                corePayment = corePaymentRepository.save(corePayment);
                
                logger.info("Started processing payment for txnRef: {} with cbsId: {}", 
                           paymentData.getTxnRef(), corePayment.getCbsId());

                // Simulate processing delay
                simulateProcessingDelay();

                // Business validation (simplified for demo)
                if (paymentData.getAmount().compareTo(new BigDecimal("100000")) > 0) {
                    corePayment.setStatus("REJECTED");
                    corePaymentRepository.save(corePayment);
                    
                    logger.warn("Payment rejected for txnRef: {} - Amount exceeds limit", paymentData.getTxnRef());
                    return new ProcessingResult("REJECTED", paymentData.getTxnRef(), 
                        corePayment.getCbsId(), null, "Amount exceeds transaction limit");
                }

                // Approve payment
                OffsetDateTime approvedAt = OffsetDateTime.now();
                corePayment.setStatus("APPROVED");
                corePayment.setApprovedAt(approvedAt);
                corePayment = corePaymentRepository.save(corePayment);

                logger.info("Payment approved for txnRef: {} with cbsId: {} at {}", 
                           paymentData.getTxnRef(), corePayment.getCbsId(), 
                           approvedAt.format(DateTimeFormatter.ISO_OFFSET_DATE_TIME));

                // Now update account balance by debiting the payer's account
                String referenceNumber = paymentData.getTxnRef().toString();
                String description = String.format("Fund Transfer to %s - %s", 
                    paymentData.getPayeeName(), paymentData.getComments() != null ? paymentData.getComments() : "");
                
                boolean balanceUpdateSuccess = accountsService.debitAccount(
                    paymentData.getPayerAccount(), 
                    paymentData.getAmount(), 
                    referenceNumber, 
                    description,
                    userAuthorization
                );

                if (!balanceUpdateSuccess) {
                    // If balance update fails, we should mark payment as failed
                    // In a real system, we might need to implement compensation/rollback
                    logger.error("Failed to update account balance for txnRef: {} - payment approved but balance not updated", 
                               paymentData.getTxnRef());
                    
                    // Update payment status to indicate balance update failure
                    corePayment.setStatus("APPROVED_BALANCE_UPDATE_FAILED");
                    corePayment = corePaymentRepository.save(corePayment);
                    
                    return new ProcessingResult("APPROVED", paymentData.getTxnRef(), 
                        corePayment.getCbsId(), approvedAt, "Payment approved but balance update failed - please contact support");
                } else {
                    logger.info("Successfully updated account balance for txnRef: {} - account {} debited by {}", 
                               paymentData.getTxnRef(), paymentData.getPayerAccount(), paymentData.getAmount());
                    
                    // Now record the transaction in the accounts service
                    // First get the current balance after debit to record properly
                    BigDecimal balanceAfterTransaction = getCurrentBalance(paymentData.getPayerAccount(), userAuthorization);
                    
                    boolean transactionRecordSuccess = accountsService.recordTransaction(
                        paymentData.getPayerAccount(),
                        "debit",
                        paymentData.getAmount(),
                        description,
                        referenceNumber,
                        balanceAfterTransaction != null ? balanceAfterTransaction : BigDecimal.ZERO,
                        "completed",
                        userAuthorization
                    );
                    
                    if (transactionRecordSuccess) {
                        logger.info("Successfully recorded transaction for txnRef: {} - account {}", 
                                   paymentData.getTxnRef(), paymentData.getPayerAccount());
                    } else {
                        logger.warn("Failed to record transaction for txnRef: {} - balance debited but transaction not recorded", 
                                   paymentData.getTxnRef());
                        // Note: We don't fail the payment for transaction recording failures,
                        // as the money has already been debited successfully
                    }
                }

                return new ProcessingResult("APPROVED", paymentData.getTxnRef(), 
                    corePayment.getCbsId(), approvedAt, null);

            } catch (Exception e) {
                logger.error("Error processing payment", e);
                return new ProcessingResult("REJECTED", null, null, null, 
                    "Internal processing error: " + e.getMessage());
            }
        });
    }

    private BigDecimal getCurrentBalance(String accountNumber, String userAuthorization) {
        try {
            // This is a simplified approach - in practice, we might get this from the debit response
            // For now, we'll make a call to accounts service to get current balance
            // TODO: Consider modifying debitAccount to return the balance after transaction
            return BigDecimal.ZERO; // Placeholder - would need to implement account lookup
        } catch (Exception e) {
            logger.warn("Failed to get current balance for account {}: {}", accountNumber, e.getMessage());
            return null;
        }
    }

    private PaymentData extractPaymentData(Map<String, Object> request) {
        try {
            PaymentData data = new PaymentData();
            
            data.setTxnRef(UUID.fromString((String) request.get("txnRef")));
            data.setPaymentType((String) request.get("paymentType"));
            data.setAmount(new BigDecimal(request.get("amount").toString()));
            data.setCurrency((String) request.get("currency"));

            // Extract payer details
            @SuppressWarnings("unchecked")
            Map<String, Object> payer = (Map<String, Object>) request.get("payer");
            data.setPayerName((String) payer.get("name"));
            data.setPayerAccount((String) payer.get("accountNo"));

            // Extract payee details
            @SuppressWarnings("unchecked")
            Map<String, Object> payee = (Map<String, Object>) request.get("payee");
            data.setPayeeName((String) payee.get("name"));
            data.setPayeeAccount((String) payee.get("accountNo"));
            data.setIfsc((String) payee.get("ifsc"));

            // Extract meta information
            @SuppressWarnings("unchecked")
            Map<String, Object> meta = (Map<String, Object>) request.get("meta");
            if (meta != null) {
                data.setComments((String) meta.get("comments"));
                String initiatedAtStr = (String) meta.get("initiatedAt");
                if (initiatedAtStr != null && !initiatedAtStr.isEmpty()) {
                    data.setInitiatedAt(OffsetDateTime.parse(initiatedAtStr));
                } else {
                    data.setInitiatedAt(OffsetDateTime.now());
                }
            } else {
                data.setInitiatedAt(OffsetDateTime.now());
            }

            return data;
        } catch (Exception e) {
            logger.error("Failed to extract payment data from request", e);
            throw new IllegalArgumentException("Invalid payment request format", e);
        }
    }

    private CorePayment createCorePayment(PaymentData data) {
        CorePayment payment = new CorePayment();
        payment.setCbsId(UUID.randomUUID());
        payment.setTxnRef(data.getTxnRef());
        payment.setStatus("PROCESSING");
        payment.setAmount(data.getAmount());
        payment.setPayerAccount(data.getPayerAccount());
        payment.setPayeeAccount(data.getPayeeAccount());
        payment.setIfsc(data.getIfsc());
        payment.setPaymentType(data.getPaymentType());
        payment.setInitiatedAt(data.getInitiatedAt());
        payment.setComments(data.getComments());
        return payment;
    }

    private void simulateProcessingDelay() {
        try {
            Thread.sleep(processingDelayMs);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            logger.warn("Processing delay interrupted", e);
        }
    }

    // Inner class for payment data
    private static class PaymentData {
        private UUID txnRef;
        private String paymentType;
        private BigDecimal amount;
        private String currency;
        private String payerName;
        private String payerAccount;
        private String payeeName;
        private String payeeAccount;
        private String ifsc;
        private String comments;
        private OffsetDateTime initiatedAt;

        // Getters and setters
        public UUID getTxnRef() { return txnRef; }
        public void setTxnRef(UUID txnRef) { this.txnRef = txnRef; }

        public String getPaymentType() { return paymentType; }
        public void setPaymentType(String paymentType) { this.paymentType = paymentType; }

        public BigDecimal getAmount() { return amount; }
        public void setAmount(BigDecimal amount) { this.amount = amount; }

        public String getCurrency() { return currency; }
        public void setCurrency(String currency) { this.currency = currency; }

        public String getPayerName() { return payerName; }
        public void setPayerName(String payerName) { this.payerName = payerName; }

        public String getPayerAccount() { return payerAccount; }
        public void setPayerAccount(String payerAccount) { this.payerAccount = payerAccount; }

        public String getPayeeName() { return payeeName; }
        public void setPayeeName(String payeeName) { this.payeeName = payeeName; }

        public String getPayeeAccount() { return payeeAccount; }
        public void setPayeeAccount(String payeeAccount) { this.payeeAccount = payeeAccount; }

        public String getIfsc() { return ifsc; }
        public void setIfsc(String ifsc) { this.ifsc = ifsc; }

        public String getComments() { return comments; }
        public void setComments(String comments) { this.comments = comments; }

        public OffsetDateTime getInitiatedAt() { return initiatedAt; }
        public void setInitiatedAt(OffsetDateTime initiatedAt) { this.initiatedAt = initiatedAt; }
    }

    // Result class
    public static class ProcessingResult {
        private final String status;
        private final UUID txnRef;
        private final UUID cbsId;
        private final OffsetDateTime approvedAt;
        private final String reason;

        public ProcessingResult(String status, UUID txnRef, UUID cbsId, 
                              OffsetDateTime approvedAt, String reason) {
            this.status = status;
            this.txnRef = txnRef;
            this.cbsId = cbsId;
            this.approvedAt = approvedAt;
            this.reason = reason;
        }

        public String getStatus() { return status; }
        public UUID getTxnRef() { return txnRef; }
        public UUID getCbsId() { return cbsId; }
        public OffsetDateTime getApprovedAt() { return approvedAt; }
        public String getReason() { return reason; }
    }
}