// Temporary APM stub to prevent errors
window.elasticApm = {
    init: function(config) {
        console.log('APM temporarily disabled');
        return {
            setUserContext: function() {},
            setCustomContext: function() {},
            addLabels: function() {},
            startTransaction: function() { return { end: function() {} }; },
            startSpan: function() { return { end: function() {} }; }
        };
    }
};