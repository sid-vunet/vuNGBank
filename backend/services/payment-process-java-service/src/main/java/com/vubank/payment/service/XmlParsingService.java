package com.vubank.payment.service;

import com.vubank.payment.model.PaymentRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import java.io.ByteArrayInputStream;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.time.format.DateTimeFormatter;
import java.util.regex.Pattern;

@Service
public class XmlParsingService {

    private static final Logger logger = LoggerFactory.getLogger(XmlParsingService.class);

    @Value("${validation.xml.max-size:1048576}")
    private int maxXmlSize;

    @Value("${validation.comments.max-length:500}")
    private int maxCommentsLength;

    @Value("${validation.ifsc.pattern:^[A-Z]{4}0[A-Z0-9]{6}$}")
    private String ifscPattern;

    private final Pattern ifscRegex;

    public XmlParsingService(@Value("${validation.ifsc.pattern:^[A-Z]{4}0[A-Z0-9]{6}$}") String pattern) {
        this.ifscRegex = Pattern.compile(pattern);
    }

    public PaymentRequest parseXmlToPaymentRequest(String xmlContent, String xRequestId, String xApiClient) {
        if (xmlContent == null || xmlContent.trim().isEmpty()) {
            throw new IllegalArgumentException("XML content cannot be empty");
        }

        if (xmlContent.length() > maxXmlSize) {
            throw new IllegalArgumentException("XML content exceeds maximum size limit");
        }

        try {
            // For demo purposes, create a simple parser
            // In production, use proper PACS XML schema validation
            PaymentRequest request = new PaymentRequest();
            
            // Extract values using simple string parsing (replace with proper XML parsing)
            request.setPayeeName(extractValue(xmlContent, "PayeeName"));
            request.setIfscCode(extractValue(xmlContent, "IFSCCode"));
            request.setPaymentType(extractValue(xmlContent, "PaymentType"));
            request.setCustomerName(extractValue(xmlContent, "CustomerName"));
            request.setFromAccountNo(extractValue(xmlContent, "FromAccountNo"));
            request.setToAccountNo(extractValue(xmlContent, "ToAccountNo"));
            request.setBranchName(extractValue(xmlContent, "BranchName"));
            request.setComments(extractValue(xmlContent, "Comments"));
            
            // Parse amount
            String amountStr = extractValue(xmlContent, "Amount");
            if (amountStr != null && !amountStr.isEmpty()) {
                request.setAmount(new BigDecimal(amountStr));
            }
            
            // Parse datetime
            String dateTimeStr = extractValue(xmlContent, "DateTime");
            if (dateTimeStr != null && !dateTimeStr.isEmpty()) {
                try {
                    request.setInitiatedAt(OffsetDateTime.parse(dateTimeStr, DateTimeFormatter.ISO_OFFSET_DATE_TIME));
                } catch (Exception e) {
                    request.setInitiatedAt(OffsetDateTime.now());
                    logger.warn("Could not parse datetime from XML, using current time: {}", e.getMessage());
                }
            } else {
                request.setInitiatedAt(OffsetDateTime.now());
            }

            // Set request metadata
            request.setXRequestId(xRequestId);
            request.setXApiClient(xApiClient);

            // Validate the parsed request
            validatePaymentRequest(request);
            
            logger.info("Successfully parsed XML to PaymentRequest for xRequestId: {}", xRequestId);
            return request;

        } catch (Exception e) {
            logger.error("Failed to parse XML content for xRequestId: {}", xRequestId, e);
            throw new IllegalArgumentException("Invalid XML content: " + e.getMessage(), e);
        }
    }

    private String extractValue(String xmlContent, String tagName) {
        String startTag = "<" + tagName + ">";
        String endTag = "</" + tagName + ">";
        
        int startIndex = xmlContent.indexOf(startTag);
        if (startIndex == -1) {
            return null;
        }
        
        int valueStart = startIndex + startTag.length();
        int endIndex = xmlContent.indexOf(endTag, valueStart);
        
        if (endIndex == -1) {
            return null;
        }
        
        return xmlContent.substring(valueStart, endIndex).trim();
    }

    private void validatePaymentRequest(PaymentRequest request) {
        if (request.getPayeeName() == null || request.getPayeeName().trim().isEmpty()) {
            throw new IllegalArgumentException("Payee name is required");
        }

        if (request.getIfscCode() == null || !ifscRegex.matcher(request.getIfscCode()).matches()) {
            throw new IllegalArgumentException("Valid IFSC code is required");
        }

        if (request.getPaymentType() == null || 
            !request.getPaymentType().matches("^(NEFT|IMPS|UPI)$")) {
            throw new IllegalArgumentException("Payment type must be NEFT, IMPS, or UPI");
        }

        if (request.getAmount() == null || request.getAmount().compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("Amount must be positive");
        }

        if (request.getFromAccountNo() == null || request.getFromAccountNo().trim().isEmpty()) {
            throw new IllegalArgumentException("From account number is required");
        }

        if (request.getToAccountNo() == null || request.getToAccountNo().trim().isEmpty()) {
            throw new IllegalArgumentException("To account number is required");
        }

        if (request.getComments() != null && request.getComments().length() > maxCommentsLength) {
            throw new IllegalArgumentException("Comments exceed maximum length of " + maxCommentsLength + " characters");
        }

        logger.debug("Payment request validation passed for amount: {} from account: {}", 
                    request.getAmount(), request.getFromAccountNo());
    }
}