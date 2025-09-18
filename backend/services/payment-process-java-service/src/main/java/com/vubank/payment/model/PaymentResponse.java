package com.vubank.payment.model;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_NULL)
public class PaymentResponse {
    
    private String txnRef;
    private String status;
    private String cbsId;
    private String approvedAt;
    private String reason;

    // Default constructor for JSON serialization
    public PaymentResponse() {
        // Required for JSON deserialization
    }

    public PaymentResponse(String txnRef, String status) {
        this.txnRef = txnRef;
        this.status = status;
    }

    public PaymentResponse(String txnRef, String status, String reason) {
        this.txnRef = txnRef;
        this.status = status;
        this.reason = reason;
    }

    // Getters and setters
    public String getTxnRef() { return txnRef; }
    public void setTxnRef(String txnRef) { this.txnRef = txnRef; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public String getCbsId() { return cbsId; }
    public void setCbsId(String cbsId) { this.cbsId = cbsId; }

    public String getApprovedAt() { return approvedAt; }
    public void setApprovedAt(String approvedAt) { this.approvedAt = approvedAt; }

    public String getReason() { return reason; }
    public void setReason(String reason) { this.reason = reason; }
}