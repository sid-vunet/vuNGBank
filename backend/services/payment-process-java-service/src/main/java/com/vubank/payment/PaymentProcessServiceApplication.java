package com.vubank.payment;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableAsync;

@SpringBootApplication
@EnableAsync
public class PaymentProcessServiceApplication {
    
    public static void main(String[] args) {
        // Attach APM agent
        try {
            co.elastic.apm.attach.ElasticApmAttacher.attach();
        } catch (Exception e) {
            System.err.println("Failed to attach APM agent: " + e.getMessage());
        }
        
        SpringApplication.run(PaymentProcessServiceApplication.class, args);
    }
}