/**
 * Elastic APM Real User Monitoring (RUM) Agent
 * Comprehensive frontend monitoring for VuNG Bank application
 * Updated: 2025-09-25 - Re-enabled with proper browser-accessible configuration
 */

// Enhanced logging for APM initialization and tracing
console.log('🔧 Initializing Elastic APM RUM Agent for VuNG Bank...');

// Global APM configuration
const APM_CONFIG = {
    // Service identification
    serviceName: 'vubank-html-frontend',
    serviceVersion: '1.2.0',
    environment: 'production',
    
    // APM Server connection (using browser-accessible URL)
    serverUrl: 'http://91.203.133.240:30200',
    
    // Transaction sampling and performance
    transactionSampleRate: 1.0,
    
    // Distributed tracing configuration
    distributedTracing: true,
    distributedTracingOrigins: [
        window.location.origin,       // Current Kong Gateway/Frontend origin
        'http://localhost:3001',      // Frontend fallback
        'http://localhost:5001',      // Backend services fallback
        'http://91.203.133.240'       // APM Server domain
    ],
    
    // Enhanced monitoring features
    capturePageLoad: true,
    disableInstrumentations: [],
    
    // User interaction tracking
    instrument: true,
    
    // Debug and logging
    logLevel: 'info',
    
    // Page lifecycle and navigation tracking
    monitorLongtasks: true,
    
    // Custom configuration for banking application
    ignoreTransactions: [
        '/health',
        '/ping'
    ]
};

console.log('📊 APM Configuration:', APM_CONFIG);

// Initialize APM with comprehensive error handling
try {
    // Load Elastic APM RUM from CDN
    if (!window.elasticApm) {
        const script = document.createElement('script');
        script.src = 'https://unpkg.com/@elastic/apm-rum@5.12.1/dist/bundles/elastic-apm-rum.umd.min.js';
        script.async = true;
        script.crossOrigin = 'anonymous';
        
        script.onload = function() {
            console.log('✅ Elastic APM RUM library loaded successfully');
            initializeAPM();
        };
        
        script.onerror = function() {
            console.warn('⚠️ Failed to load APM RUM library from CDN, using fallback');
            createAPMFallback();
        };
        
        document.head.appendChild(script);
    } else {
        initializeAPM();
    }
} catch (error) {
    console.warn('⚠️ APM initialization error, using fallback:', error);
    createAPMFallback();
}

function initializeAPM() {
    try {
        // Initialize APM agent
        const apm = window.elasticApm.init(APM_CONFIG);
        
        if (apm) {
            console.log('🎉 APM Agent initialized successfully!');
            
            // Set user context for banking transactions
            if (localStorage.getItem('username')) {
                apm.setUserContext({
                    id: localStorage.getItem('customerId') || 'anonymous',
                    username: localStorage.getItem('username'),
                    email: localStorage.getItem('userEmail') || 'unknown@vubank.com'
                });
                console.log('👤 User context set for APM tracking');
            }
            
            // Set custom context for banking application
            apm.setCustomContext({
                application: 'VuNG Bank',
                module: 'HTML Frontend',
                version: '1.2.0',
                platform: 'web'
            });
            
            // Add banking-specific labels
            apm.addLabels({
                bank: 'VuNG Bank',
                frontend_type: 'html',
                distributed_tracing: 'enabled'
            });
            
            // Start page load transaction
            const pageTransaction = apm.startTransaction('page-load', 'page-load');
            if (pageTransaction) {
                pageTransaction.addLabels({
                    page: window.location.pathname,
                    user_agent: navigator.userAgent
                });
                
                // End transaction when page is fully loaded
                window.addEventListener('load', () => {
                    pageTransaction.end();
                    console.log('📈 Page load transaction completed');
                });
            }
            
            // Expose APM globally for banking operations
            window.vubankAPM = apm;
            console.log('🌐 APM exposed as window.vubankAPM for banking operations');
            
        } else {
            console.warn('⚠️ APM agent initialization returned null, using fallback');
            createAPMFallback();
        }
        
    } catch (error) {
        console.warn('⚠️ APM agent initialization failed:', error);
        createAPMFallback();
    }
}

function createAPMFallback() {
    console.log('🔄 Creating APM fallback interface...');
    
    // Fallback APM interface that logs operations
    window.vubankAPM = {
        init: function(config) {
            console.log('APM Fallback: init called with config:', config);
            return this;
        },
        setUserContext: function(context) {
            console.log('APM Fallback: setUserContext:', context);
        },
        setCustomContext: function(context) {
            console.log('APM Fallback: setCustomContext:', context);
        },
        addLabels: function(labels) {
            console.log('APM Fallback: addLabels:', labels);
        },
        startTransaction: function(name, type) {
            console.log('APM Fallback: startTransaction:', name, type);
            return {
                addLabels: function(labels) {
                    console.log('APM Fallback Transaction: addLabels:', labels);
                },
                end: function() {
                    console.log('APM Fallback Transaction: end');
                }
            };
        },
        startSpan: function(name, type) {
            console.log('APM Fallback: startSpan:', name, type);
            return {
                addLabels: function(labels) {
                    console.log('APM Fallback Span: addLabels:', labels);
                },
                end: function() {
                    console.log('APM Fallback Span: end');
                }
            };
        }
    };
    
    console.log('✅ APM fallback interface created');
}

// Utility functions for banking operations
window.vubankAPMUtils = {
    // Track banking transactions
    trackTransaction: function(transactionType, amount, fromAccount, toAccount) {
        if (window.vubankAPM && window.vubankAPM.startTransaction) {
            const transaction = window.vubankAPM.startTransaction(`banking-${transactionType}`, 'banking');
            if (transaction) {
                transaction.addLabels({
                    transaction_type: transactionType,
                    amount: amount,
                    from_account: fromAccount,
                    to_account: toAccount,
                    timestamp: new Date().toISOString()
                });
                return transaction;
            }
        }
        return null;
    },
    
    // Track API calls with distributed tracing
    trackAPICall: function(endpoint, method = 'GET') {
        if (window.vubankAPM && window.vubankAPM.startSpan) {
            const span = window.vubankAPM.startSpan(`api-${method.toLowerCase()}-${endpoint.replace(/[^a-zA-Z0-9]/g, '-')}`, 'http');
            if (span) {
                span.addLabels({
                    endpoint: endpoint,
                    method: method,
                    service: 'kong-gateway'
                });
                return span;
            }
        }
        return null;
    }
};

console.log('🎯 VuNG Bank APM RUM Agent initialization complete!');