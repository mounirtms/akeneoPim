/**
 * Navigation Guard - Prevents "function () { [native code] }" navigation bug
 * This script intercepts navigation attempts and validates them before routing
 */
(function() {
    'use strict';
    
    // Store original navigation functions
    var originalPushState = history.pushState;
    var originalReplaceState = history.replaceState;
    
    // Helper to validate URLs
    function isValidUrl(url) {
        if (!url || typeof url !== 'string') {
            return false;
        }
        // Reject URLs containing function toString output
        if (url.indexOf('function') !== -1 || url.indexOf('[native code]') !== -1) {
            console.warn('Navigation guard: Rejected invalid URL:', url);
            return false;
        }
        return true;
    }
    
    // Override pushState
    history.pushState = function() {
        var url = arguments[2];
        if (url && !isValidUrl(url)) {
            console.warn('Navigation guard: Blocked pushState with invalid URL');
            return;
        }
        return originalPushState.apply(history, arguments);
    };
    
    // Override replaceState
    history.replaceState = function() {
        var url = arguments[2];
        if (url && !isValidUrl(url)) {
            console.warn('Navigation guard: Blocked replaceState with invalid URL');
            return;
        }
        return originalReplaceState.apply(history, arguments);
    };
    
    // Intercept anchor clicks
    document.addEventListener('click', function(e) {
        var target = e.target;
        while (target && target !== document) {
            if (target.tagName === 'A' && target.getAttribute('href')) {
                var href = target.getAttribute('href');
                if (!isValidUrl(href)) {
                    e.preventDefault();
                    console.warn('Navigation guard: Blocked navigation to invalid URL:', href);
                    return false;
                }
            }
            target = target.parentNode;
        }
    }, true);
    
    console.log('Navigation guard initialized');
})();
