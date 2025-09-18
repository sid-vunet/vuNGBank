package com.vubank.payment.model;

import com.fasterxml.jackson.annotation.JsonFormat;
import com.fasterxml.jackson.annotation.JsonInclude;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

@JsonInclude(JsonInclude.Include.NON_NULL)
public class PaymentRequest {

    @NotBlank(message = "Payee name is required")
    private String payeeName;

    @NotBlank(message = "IFSC code is required")
    @Pattern(regexp = "^[A-Z]{4}0[A-Z0-9]{6}$", message = "Invalid IFSC code format")
    private String ifscCode;

    @NotBlank(message = "Payment type is required")
    @Pattern(regexp = "^(NEFT|IMPS|UPI)$", message = "Payment type must be NEFT, IMPS, or UPI")
    private String paymentType;

    @NotNull(message = "Initiation date is required")
    @JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd'T'HH:mm:ss.SSSXXX")
    private OffsetDateTime initiatedAt;

    @NotBlank(message = "Customer name is required")
    private String customerName;

    @NotBlank(message = "From account number is required")
    private String fromAccountNo;

    @NotBlank(message = "To account number is required")
    private String toAccountNo;

    @NotBlank(message = "Branch name is required")
    private String branchName;

    @NotNull(message = "Amount is required")
    @Positive(message = "Amount must be positive")
    private BigDecimal amount;

    private String comments;

    // Request metadata
    private String xRequestId;
    private String xApiClient;

    // Default constructor
    public PaymentRequest() {}

    // Getters and setters
    public String getPayeeName() { return payeeName; }
    public void setPayeeName(String payeeName) { this.payeeName = payeeName; }

    public String getIfscCode() { return ifscCode; }
    public void setIfscCode(String ifscCode) { this.ifscCode = ifscCode; }

    public String getPaymentType() { return paymentType; }
    public void setPaymentType(String paymentType) { this.paymentType = paymentType; }

    public OffsetDateTime getInitiatedAt() { return initiatedAt; }
    public void setInitiatedAt(OffsetDateTime initiatedAt) { this.initiatedAt = initiatedAt; }

    public String getCustomerName() { return customerName; }
    public void setCustomerName(String customerName) { this.customerName = customerName; }

    public String getFromAccountNo() { return fromAccountNo; }
    public void setFromAccountNo(String fromAccountNo) { this.fromAccountNo = fromAccountNo; }

    public String getToAccountNo() { return toAccountNo; }
    public void setToAccountNo(String toAccountNo) { this.toAccountNo = toAccountNo; }

    public String getBranchName() { return branchName; }
    public void setBranchName(String branchName) { this.branchName = branchName; }

    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }

    public String getComments() { return comments; }
    public void setComments(String comments) { this.comments = comments; }

    public String getXRequestId() { return xRequestId; }
    public void setXRequestId(String xRequestId) { this.xRequestId = xRequestId; }

    public String getXApiClient() { return xApiClient; }
    public void setXApiClient(String xApiClient) { this.xApiClient = xApiClient; }
}