package com.vubank.pdf;

import co.elastic.apm.attach.ElasticApmAttacher;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@SpringBootApplication
public class PdfReceiptServiceApplication {

    public static void main(String[] args) {
        // Initialize comprehensive APM with maximum observability (matching RUM configuration)
        System.out.println("🔧 Initializing comprehensive APM configuration for PDF Receipt service...");
        
        // Set comprehensive APM environment variables for maximum observability
        setApmProperty("ELASTIC_APM_SERVICE_NAME", "pdf-receipt-java-service");
        setApmProperty("ELASTIC_APM_SERVICE_VERSION", "1.0.0");
        setApmProperty("ELASTIC_APM_ENVIRONMENT", "production");
        setApmProperty("ELASTIC_APM_SERVER_URL", "http://91.203.133.240:30200");
        
        // Sampling configuration (100% like RUM)
        setApmProperty("ELASTIC_APM_TRANSACTION_SAMPLE_RATE", "1.0");
        setApmProperty("ELASTIC_APM_SPAN_SAMPLE_RATE", "1.0");
        
        // Data capture configuration (maximum like RUM)
        setApmProperty("ELASTIC_APM_CAPTURE_BODY", "all");
        setApmProperty("ELASTIC_APM_CAPTURE_HEADERS", "true");
        
        // Distributed tracing configuration (matching RUM distributedTracingOrigins)
        setApmProperty("ELASTIC_APM_USE_DISTRIBUTED_TRACING", "true");
        setApmProperty("ELASTIC_APM_SPAN_FRAMES_MIN_DURATION", "0ms");
        
        // Advanced configuration for maximum observability
        setApmProperty("ELASTIC_APM_LOG_LEVEL", "INFO");
        setApmProperty("ELASTIC_APM_RECORDING", "true");
        setApmProperty("ELASTIC_APM_STACK_TRACE_LIMIT", "50");
        setApmProperty("ELASTIC_APM_SPAN_STACK_TRACE_MIN_DURATION", "0ms");
        
        // Performance monitoring settings
        setApmProperty("ELASTIC_APM_DISABLE_METRICS", "false");
        setApmProperty("ELASTIC_APM_METRICS_INTERVAL", "30s");
        setApmProperty("ELASTIC_APM_MAX_QUEUE_SIZE", "1000");
        setApmProperty("ELASTIC_APM_FLUSH_INTERVAL", "1s");
        setApmProperty("ELASTIC_APM_TRANSACTION_MAX_SPANS", "500");
        
        // Java-specific comprehensive monitoring for PDF generation
        setApmProperty("ELASTIC_APM_ENABLE_LOG_CORRELATION", "true");
        setApmProperty("ELASTIC_APM_APPLICATION_PACKAGES", "com.vubank.pdf");
        setApmProperty("ELASTIC_APM_PROFILING_INFERRED_SPANS_ENABLED", "true");
        setApmProperty("ELASTIC_APM_PROFILING_INFERRED_SPANS_MIN_DURATION", "0ms");
        setApmProperty("ELASTIC_APM_INSTRUMENT", "true");
        setApmProperty("ELASTIC_APM_TRACE_METHODS", "com.vubank.pdf.*");
        
        try {
            ElasticApmAttacher.attach();
            System.out.println("✅ APM Agent attached successfully with comprehensive configuration");
            System.out.println("   Service: pdf-receipt-java-service v1.0.0 (production)");
            System.out.println("   Features: PDF generation monitoring, HTTP tracing, method instrumentation");
            System.out.println("   Monitoring: Maximum observability matching RUM frontend");
        } catch (Exception e) {
            System.err.println("❌ Failed to attach APM agent: " + e.getMessage());
            e.printStackTrace();
        }
        
        SpringApplication.run(PdfReceiptServiceApplication.class, args);
    }
    
    private static void setApmProperty(String key, String value) {
        if (System.getProperty(key) == null && System.getenv(key) == null) {
            System.setProperty(key, value);
        }
    }
    
    @Configuration
    public static class CorsConfig implements WebMvcConfigurer {
        @Override
        public void addCorsMappings(CorsRegistry registry) {
            registry.addMapping("/**")
                    .allowedOrigins("*")
                    .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                    .allowedHeaders("Origin", "X-Requested-With", "Content-Type", "Accept", 
                                  "Authorization", "X-Api-Client", "X-Request-ID", 
                                  "traceparent", "tracestate", "elastic-apm-traceparent")
                    .exposedHeaders("X-Service-Name", "X-Service-Version", 
                                  "traceparent", "tracestate", "elastic-apm-traceparent");
        }
    }
}