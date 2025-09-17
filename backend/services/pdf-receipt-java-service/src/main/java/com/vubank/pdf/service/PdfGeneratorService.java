package com.vubank.pdf.service;

import com.itextpdf.text.*;
import com.itextpdf.text.pdf.*;
import com.itextpdf.text.pdf.draw.LineSeparator;
import com.vubank.pdf.model.TransactionReceipt;
import org.springframework.stereotype.Service;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.time.format.DateTimeFormatter;

@Service
public class PdfGeneratorService {

    private static final Font TITLE_FONT = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 18, BaseColor.DARK_GRAY);
    private static final Font HEADER_FONT = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 14, BaseColor.BLACK);
    private static final Font NORMAL_FONT = FontFactory.getFont(FontFactory.HELVETICA, 12, BaseColor.BLACK);
    private static final Font SMALL_FONT = FontFactory.getFont(FontFactory.HELVETICA, 10, BaseColor.GRAY);

    public byte[] generateReceiptPdf(TransactionReceipt receipt) throws DocumentException, IOException {
        Document document = new Document(PageSize.A4, 50, 50, 50, 50);
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        
        try {
            PdfWriter.getInstance(document, baos);
            document.open();

            // Add VuBank header
            addHeader(document);
            
            // Add transaction receipt content
            addReceiptContent(document, receipt);
            
            // Add footer
            addFooter(document);
            
        } finally {
            document.close();
        }
        
        return baos.toByteArray();
    }

    private void addHeader(Document document) throws DocumentException {
        // VuBank Logo and Title
        Paragraph title = new Paragraph("VuBank", TITLE_FONT);
        title.setAlignment(Element.ALIGN_CENTER);
        title.setSpacingAfter(10);
        document.add(title);

        Paragraph subtitle = new Paragraph("Next Generation Banking", NORMAL_FONT);
        subtitle.setAlignment(Element.ALIGN_CENTER);
        subtitle.setSpacingAfter(20);
        document.add(subtitle);

        // Receipt Title
        Paragraph receiptTitle = new Paragraph("TRANSACTION RECEIPT", HEADER_FONT);
        receiptTitle.setAlignment(Element.ALIGN_CENTER);
        receiptTitle.setSpacingAfter(20);
        document.add(receiptTitle);

        // Add a line separator
        LineSeparator line = new LineSeparator(1, 100, BaseColor.LIGHT_GRAY, Element.ALIGN_CENTER, -2);
        document.add(new Chunk(line));
        document.add(new Paragraph(" ")); // Add space
    }

    private void addReceiptContent(Document document, TransactionReceipt receipt) throws DocumentException {
        // Create a table for transaction details
        PdfPTable table = new PdfPTable(2);
        table.setWidthPercentage(100);
        table.setSpacingBefore(10);
        table.setSpacingAfter(10);
        
        // Set column widths (40% for labels, 60% for values)
        float[] columnWidths = {40f, 60f};
        table.setWidths(columnWidths);

        // Add transaction details
        addTableRow(table, "Transaction ID:", receipt.getTransactionId());
        addTableRow(table, "Date & Time:", receipt.getTimestamp().format(DateTimeFormatter.ofPattern("dd-MM-yyyy HH:mm:ss")));
        addTableRow(table, "Status:", receipt.getStatus());
        
        // Add empty row for spacing
        addEmptyRow(table);
        
        // Customer details
        addTableRow(table, "Customer Name:", receipt.getCustomerName());
        addTableRow(table, "Customer ID:", receipt.getCustomerId());
        
        // Add empty row for spacing
        addEmptyRow(table);
        
        // Transaction details
        addTableRow(table, "From Account:", receipt.getFromAccount());
        addTableRow(table, "To Account:", receipt.getToAccount());
        addTableRow(table, "Payee Name:", receipt.getPayeeName());
        addTableRow(table, "Payment Mode:", receipt.getPaymentMode());
        
        // Add empty row for spacing
        addEmptyRow(table);
        
        // Amount (highlighted)
        PdfPCell amountLabelCell = new PdfPCell(new Phrase("Amount:", HEADER_FONT));
        amountLabelCell.setBorder(Rectangle.NO_BORDER);
        amountLabelCell.setPadding(8);
        table.addCell(amountLabelCell);
        
        PdfPCell amountValueCell = new PdfPCell(new Phrase("₹" + String.format("%.2f", receipt.getAmount()), HEADER_FONT));
        amountValueCell.setBorder(Rectangle.NO_BORDER);
        amountValueCell.setPadding(8);
        amountValueCell.setBackgroundColor(new BaseColor(240, 248, 255)); // Light blue background
        table.addCell(amountValueCell);

        document.add(table);
    }

    private void addTableRow(PdfPTable table, String label, String value) {
        PdfPCell labelCell = new PdfPCell(new Phrase(label, NORMAL_FONT));
        labelCell.setBorder(Rectangle.NO_BORDER);
        labelCell.setPadding(8);
        table.addCell(labelCell);
        
        PdfPCell valueCell = new PdfPCell(new Phrase(value != null ? value : "N/A", NORMAL_FONT));
        valueCell.setBorder(Rectangle.NO_BORDER);
        valueCell.setPadding(8);
        table.addCell(valueCell);
    }

    private void addEmptyRow(PdfPTable table) {
        PdfPCell emptyCell1 = new PdfPCell(new Phrase(" ", SMALL_FONT));
        emptyCell1.setBorder(Rectangle.NO_BORDER);
        emptyCell1.setPadding(4);
        table.addCell(emptyCell1);
        
        PdfPCell emptyCell2 = new PdfPCell(new Phrase(" ", SMALL_FONT));
        emptyCell2.setBorder(Rectangle.NO_BORDER);
        emptyCell2.setPadding(4);
        table.addCell(emptyCell2);
    }

    private void addFooter(Document document) throws DocumentException {
        document.add(new Paragraph(" ")); // Add space
        
        // Add line separator
        LineSeparator line = new LineSeparator(1, 100, BaseColor.LIGHT_GRAY, Element.ALIGN_CENTER, -2);
        document.add(new Chunk(line));
        
        Paragraph footer1 = new Paragraph("This is a computer-generated receipt and does not require a signature.", SMALL_FONT);
        footer1.setAlignment(Element.ALIGN_CENTER);
        footer1.setSpacingBefore(10);
        document.add(footer1);
        
        Paragraph footer2 = new Paragraph("For any queries, please contact VuBank Customer Support: 1800-VUBANK", SMALL_FONT);
        footer2.setAlignment(Element.ALIGN_CENTER);
        footer2.setSpacingAfter(10);
        document.add(footer2);
    }
}