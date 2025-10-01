// ========================================
// STANDARD VUBANK RUM CONFIGURATION
// ========================================
// This is the unified RUM configuration used across all HTML files
// Only pageLoadTransactionName should be customized per page

window.elasticApm = elasticApm.init({
    // === CORE CONFIGURATION ===
    serviceName: 'vubank-frontend',
    serverUrl: 'http://91.203.133.240:30200',
    serviceVersion: '1.0.0',
    environment: 'e2e-240-dev',
    
    // === DISTRIBUTED TRACING ===
    distributedTracing: true,
    distributedTracingOrigins: [
        // Current page origin
        window.location.origin,
        
        // Frontend endpoints
        'http://localhost:3001',
        'http://localhost:3000',
        
        // Backend microservices
        'http://login-go-service:8000',
        'http://login-python-authenticator:8001', 
        'http://accounts-go-service:8002',
        'http://pdf-receipt-java-service:8003',
        'http://payment-process-java-service:8004',
        'http://corebanking-java-service:8005',
        'http://payee-store-dotnet-service:5004',
        
        // Local development endpoints
        'http://localhost:8000',
        'http://localhost:8001',
        'http://localhost:8002', 
        'http://localhost:8003',
        'http://localhost:8004',
        'http://localhost:8005',
        'http://localhost:5004',
        
        // APM server endpoints
        'http://91.203.133.240:30200',
        'http://apm-server:30200',
        'https://91.203.133.240:30200',
        'https://apm-server:30200',
        
        // Docker compose service names
        'http://vubank-frontend:3000',
        'http://vubank-html-frontend:80',
        
        // Catch-all
        '*'
    ],
    
    // === INSTRUMENTATION ===
    disableInstrumentations: [],
    instrumentFetch: true,
    instrumentXMLHttpRequest: true,
    captureHeaders: true,
    captureBody: 'all',
    
    // === PAGE LOAD ===
    capturePageLoad: true,
    capturePageLoadSpans: true,
    pageLoadTransactionName: 'PAGE_SPECIFIC_TRANSACTION_NAME', // TO BE REPLACED
    pageLoadSpanId: true,
    
    // === USER INTERACTIONS ===
    captureUserInteractions: true,
    userInteractionTimeout: 5000,
    
    // === NAVIGATION ===
    captureNavigation: true,
    
    // === ERROR CAPTURE ===
    captureErrors: true,
    errorThrottleLimit: 200,
    errorThrottleInterval: 30000,
    captureUnhandledRejections: true,
    
    // === PERFORMANCE ===
    transactionSampleRate: 1.0,
    spanSampleRate: 1.0,
    transactionTimeout: 30000,
    captureResourceTimings: true,
    breakdownMetrics: true,
    
    // === SESSION ===
    session: true,
    sessionTimeout: 1800000, // 30 minutes
    
    // === SPAN CONFIGURATION ===
    spanStackTraceMinDuration: 0,
    spanCompressionEnabled: false,
    captureSpanStackTraces: true,
    
    // === LOGGING ===
    logLevel: 'debug',
    sendCredentials: false,
    
    // === METADATA ===
    sourcemapsEnabled: true,
    propagateTracestate: true,
    
    // === CONTEXT ===
    context: {
        user: {
            id: 'auto-detected',
            username: 'auto-detected', 
            email: 'auto-detected'
        },
        custom: {
            application: 'vubank-frontend',
            version: '1.0.0'
        }
    },
    
    // === LONG TASK MONITORING ===
    longTask: {
        threshold: 50
    },
    
    // === CENTRAL CONFIGURATION ===
    centralConfig: true,
    
    // === PERFORMANCE ===
    memoryLimit: 10485760, // 10MB
    queueLimit: 1000,
    flushInterval: 500,
    
    // === EXPERIMENTAL ===
    experimental: {
        asyncStack: true
    },
    
    // === ADVANCED ===
    apiRequestTime: true,
    apiRequestSize: true,
    browserHistory: true,
    active: true
});