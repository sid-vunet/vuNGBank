package com.vubank.pdf.model;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.time.LocalDateTime;

public class TransactionReceipt {
    
    @JsonProperty("transactionId")
    private String transactionId;
    
    @JsonProperty("fromAccount")
    private String fromAccount;
    
    @JsonProperty("toAccount") 
    private String toAccount;
    
    @JsonProperty("payeeName")
    private String payeeName;
    
    @JsonProperty("amount")
    private Double amount;
    
    @JsonProperty("paymentMode")
    private String paymentMode;
    
    @JsonProperty("timestamp")
    private LocalDateTime timestamp;
    
    @JsonProperty("status")
    private String status;
    
    @JsonProperty("customerName")
    private String customerName;
    
    @JsonProperty("customerId")
    private String customerId;

    // Default constructor
    public TransactionReceipt() {}

    // Constructor with all fields
    public TransactionReceipt(String transactionId, String fromAccount, String toAccount, 
                            String payeeName, Double amount, String paymentMode, 
                            LocalDateTime timestamp, String status, String customerName, String customerId) {
        this.transactionId = transactionId;
        this.fromAccount = fromAccount;
        this.toAccount = toAccount;
        this.payeeName = payeeName;
        this.amount = amount;
        this.paymentMode = paymentMode;
        this.timestamp = timestamp;
        this.status = status;
        this.customerName = customerName;
        this.customerId = customerId;
    }

    // Getters and Setters
    public String getTransactionId() { return transactionId; }
    public void setTransactionId(String transactionId) { this.transactionId = transactionId; }

    public String getFromAccount() { return fromAccount; }
    public void setFromAccount(String fromAccount) { this.fromAccount = fromAccount; }

    public String getToAccount() { return toAccount; }
    public void setToAccount(String toAccount) { this.toAccount = toAccount; }

    public String getPayeeName() { return payeeName; }
    public void setPayeeName(String payeeName) { this.payeeName = payeeName; }

    public Double getAmount() { return amount; }
    public void setAmount(Double amount) { this.amount = amount; }

    public String getPaymentMode() { return paymentMode; }
    public void setPaymentMode(String paymentMode) { this.paymentMode = paymentMode; }

    public LocalDateTime getTimestamp() { return timestamp; }
    public void setTimestamp(LocalDateTime timestamp) { this.timestamp = timestamp; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public String getCustomerName() { return customerName; }
    public void setCustomerName(String customerName) { this.customerName = customerName; }

    public String getCustomerId() { return customerId; }
    public void setCustomerId(String customerId) { this.customerId = customerId; }
}