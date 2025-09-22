package com.vubank.core;

import co.elastic.apm.attach.ElasticApmAttacher;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class CoreBankingServiceApplication {

    public static void main(String[] args) {
        // Attach Elastic APM agent programmatically
        ElasticApmAttacher.attach();
        
        SpringApplication.run(CoreBankingServiceApplication.class, args);
    }
}