package com.vubank.pdf.controller;

import com.vubank.pdf.model.TransactionReceipt;
import com.vubank.pdf.service.PdfGeneratorService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

@RestController
@RequestMapping("/api/pdf")
@CrossOrigin(origins = "*")
public class PdfReceiptController {

    @Autowired
    private PdfGeneratorService pdfGeneratorService;

    @PostMapping("/generate-receipt")
    public ResponseEntity<byte[]> generateReceipt(@RequestBody TransactionReceipt receipt) {
        try {
            // Generate PDF
            byte[] pdfBytes = pdfGeneratorService.generateReceiptPdf(receipt);
            
            // Create filename with timestamp
            String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss"));
            String filename = String.format("VuBank_Receipt_%s_%s.pdf", receipt.getTransactionId(), timestamp);
            
            // Set response headers
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_PDF);
            headers.setContentDispositionFormData("attachment", filename);
            headers.setContentLength(pdfBytes.length);
            
            return new ResponseEntity<>(pdfBytes, headers, HttpStatus.OK);
            
        } catch (Exception e) {
            return new ResponseEntity<>(HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    @GetMapping("/health")
    public ResponseEntity<String> healthCheck() {
        return ResponseEntity.ok("PDF Receipt Service is running");
    }
}