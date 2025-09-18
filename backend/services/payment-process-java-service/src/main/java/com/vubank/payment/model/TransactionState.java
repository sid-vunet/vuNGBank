package com.vubank.payment.model;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

@JsonInclude(JsonInclude.Include.NON_NULL)
public class TransactionState {
    
    public enum Status {
        RECEIVED, VALIDATED, IN_PROGRESS, SUCCESS, FAILED, INITIATED
    }

    private String txnRef;
    private String transactionRef; // Alias for txnRef for compatibility
    private Status status;
    private String payloadXml;
    private String payloadJson;
    private String paymentType;
    private BigDecimal amount;
    private String payerAccount;
    private String payeeAccount;
    private String payeeName;
    private String fromAccountNo;
    private String toAccountNo;
    private String ifsc;
    private String ifscCode;
    private String comments;
    
    // Timestamps
    private OffsetDateTime createdAt;
    private OffsetDateTime updatedAt;
    private OffsetDateTime processedAt;
    private OffsetDateTime validatedAt;
    private OffsetDateTime inProgressAt;
    private OffsetDateTime approvedAt;
    
    // CoreBanking response
    private String cbsId;
    private String failureReason;
    private String coreBankingResponse;

    // Request metadata
    private String xRequestId;
    private String xApiClient;

    // Default constructor for JSON serialization
    public TransactionState() {
        // Required for JSON deserialization
    }

    // Constructor with txnRef
    public TransactionState(String txnRef) {
        this.txnRef = txnRef;
        this.status = Status.RECEIVED;
        this.createdAt = OffsetDateTime.now();
    }

    // Getters and setters
    public String getTxnRef() { return txnRef; }
    public void setTxnRef(String txnRef) { this.txnRef = txnRef; }

    public Status getStatus() { return status; }
    public void setStatus(Status status) { this.status = status; }

    public String getPayloadXml() { return payloadXml; }
    public void setPayloadXml(String payloadXml) { this.payloadXml = payloadXml; }

    public String getPayloadJson() { return payloadJson; }
    public void setPayloadJson(String payloadJson) { this.payloadJson = payloadJson; }

    public String getPaymentType() { return paymentType; }
    public void setPaymentType(String paymentType) { this.paymentType = paymentType; }

    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }

    public String getPayerAccount() { return payerAccount; }
    public void setPayerAccount(String payerAccount) { this.payerAccount = payerAccount; }

    public String getPayeeAccount() { return payeeAccount; }
    public void setPayeeAccount(String payeeAccount) { this.payeeAccount = payeeAccount; }

    public String getIfsc() { return ifsc; }
    public void setIfsc(String ifsc) { this.ifsc = ifsc; }

    public String getComments() { return comments; }
    public void setComments(String comments) { this.comments = comments; }

    public OffsetDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(OffsetDateTime createdAt) { this.createdAt = createdAt; }

    public OffsetDateTime getValidatedAt() { return validatedAt; }
    public void setValidatedAt(OffsetDateTime validatedAt) { this.validatedAt = validatedAt; }

    public OffsetDateTime getInProgressAt() { return inProgressAt; }
    public void setInProgressAt(OffsetDateTime inProgressAt) { this.inProgressAt = inProgressAt; }

    public OffsetDateTime getApprovedAt() { return approvedAt; }
    public void setApprovedAt(OffsetDateTime approvedAt) { this.approvedAt = approvedAt; }

    public String getCbsId() { return cbsId; }
    public void setCbsId(String cbsId) { this.cbsId = cbsId; }

    public String getFailureReason() { return failureReason; }
    public void setFailureReason(String failureReason) { this.failureReason = failureReason; }

    public String getXRequestId() { return xRequestId; }
    public void setXRequestId(String xRequestId) { this.xRequestId = xRequestId; }

    public String getXApiClient() { return xApiClient; }
    public void setXApiClient(String xApiClient) { this.xApiClient = xApiClient; }

    // Additional getters/setters for compatibility
    public String getTransactionRef() { return txnRef; }
    public void setTransactionRef(String transactionRef) { this.txnRef = transactionRef; }

    public String getPayeeName() { return payeeName; }
    public void setPayeeName(String payeeName) { this.payeeName = payeeName; }

    public String getFromAccountNo() { return fromAccountNo; }
    public void setFromAccountNo(String fromAccountNo) { this.fromAccountNo = fromAccountNo; }

    public String getToAccountNo() { return toAccountNo; }
    public void setToAccountNo(String toAccountNo) { this.toAccountNo = toAccountNo; }

    public String getIfscCode() { return ifscCode; }
    public void setIfscCode(String ifscCode) { this.ifscCode = ifscCode; }

    public OffsetDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(OffsetDateTime updatedAt) { this.updatedAt = updatedAt; }

    public OffsetDateTime getProcessedAt() { return processedAt; }
    public void setProcessedAt(OffsetDateTime processedAt) { this.processedAt = processedAt; }

    public String getCoreBankingResponse() { return coreBankingResponse; }
    public void setCoreBankingResponse(String coreBankingResponse) { this.coreBankingResponse = coreBankingResponse; }
}