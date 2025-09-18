package com.vubank.core;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class CoreBankingServiceApplication {

    public static void main(String[] args) {
        // Attach APM agent
        try {
            co.elastic.apm.attach.ElasticApmAttacher.attach();
        } catch (Exception e) {
            // Log startup error but continue
            System.err.println("Failed to attach APM agent: " + e.getMessage());
        }
        
        SpringApplication.run(CoreBankingServiceApplication.class, args);
    }
}