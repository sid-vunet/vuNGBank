package com.vubank.core.model;

import com.fasterxml.jackson.annotation.JsonFormat;
import jakarta.persistence.*;
import org.hibernate.annotations.CreationTimestamp;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "core_payments")
public class CorePayment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "cbs_id", nullable = false, unique = true)
    private UUID cbsId;

    @Column(name = "txn_ref", nullable = false, unique = true)
    private UUID txnRef;

    @Column(name = "status", nullable = false, length = 20)
    private String status;

    @Column(name = "amount", nullable = false, precision = 15, scale = 2)
    private BigDecimal amount;

    @Column(name = "payer_account", nullable = false, length = 50)
    private String payerAccount;

    @Column(name = "payee_account", nullable = false, length = 50)
    private String payeeAccount;

    @Column(name = "ifsc", nullable = false, length = 11)
    private String ifsc;

    @Column(name = "payment_type", nullable = false, length = 10)
    private String paymentType;

    @Column(name = "initiated_at", nullable = false)
    @JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd'T'HH:mm:ss.SSSXXX")
    private OffsetDateTime initiatedAt;

    @Column(name = "approved_at")
    @JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd'T'HH:mm:ss.SSSXXX")
    private OffsetDateTime approvedAt;

    @Column(name = "comments", length = 500)
    private String comments;

    @Column(name = "raw_json", columnDefinition = "jsonb")
    @org.hibernate.annotations.JdbcTypeCode(org.hibernate.type.SqlTypes.JSON)
    private String rawJson;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    // Default constructor for JPA
    public CorePayment() {
        // Required for JPA entity instantiation
    }

    // Constructor with required fields
    public CorePayment(UUID txnRef, String status, BigDecimal amount, 
                      String payerAccount, String payeeAccount, String ifsc, 
                      String paymentType, OffsetDateTime initiatedAt) {
        this.cbsId = UUID.randomUUID();
        this.txnRef = txnRef;
        this.status = status;
        this.amount = amount;
        this.payerAccount = payerAccount;
        this.payeeAccount = payeeAccount;
        this.ifsc = ifsc;
        this.paymentType = paymentType;
        this.initiatedAt = initiatedAt;
    }

    // Getters and setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public UUID getCbsId() { return cbsId; }
    public void setCbsId(UUID cbsId) { this.cbsId = cbsId; }

    public UUID getTxnRef() { return txnRef; }
    public void setTxnRef(UUID txnRef) { this.txnRef = txnRef; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }

    public String getPayerAccount() { return payerAccount; }
    public void setPayerAccount(String payerAccount) { this.payerAccount = payerAccount; }

    public String getPayeeAccount() { return payeeAccount; }
    public void setPayeeAccount(String payeeAccount) { this.payeeAccount = payeeAccount; }

    public String getIfsc() { return ifsc; }
    public void setIfsc(String ifsc) { this.ifsc = ifsc; }

    public String getPaymentType() { return paymentType; }
    public void setPaymentType(String paymentType) { this.paymentType = paymentType; }

    public OffsetDateTime getInitiatedAt() { return initiatedAt; }
    public void setInitiatedAt(OffsetDateTime initiatedAt) { this.initiatedAt = initiatedAt; }

    public OffsetDateTime getApprovedAt() { return approvedAt; }
    public void setApprovedAt(OffsetDateTime approvedAt) { this.approvedAt = approvedAt; }

    public String getComments() { return comments; }
    public void setComments(String comments) { this.comments = comments; }

    public String getRawJson() { return rawJson; }
    public void setRawJson(String rawJson) { this.rawJson = rawJson; }

    public OffsetDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(OffsetDateTime createdAt) { this.createdAt = createdAt; }
}