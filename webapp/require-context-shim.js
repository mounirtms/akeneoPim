// Require-context shim for Akeneo PIM
// This module provides the require.context() functionality expected by form-builder
define(function() {
    'use strict';
    
    console.log('[require-context] Shim loaded');
    
    // Return a function that mimics webpack's require.context()
    return function requireContext(directory, useSubdirectories, regExp) {
        console.log('[require-context] Creating context:', directory, useSubdirectories, regExp);
        
        var context = function(request) {
            console.log('[require-context] Loading:', request);
            // Delegate to RequireJS
            return require(request);
        };
        
        // Mock the keys() method
        context.keys = function() {
            console.log('[require-context] keys() called');
            return [];
        };
        
        context.resolve = function(request) {
            return request;
        };
        
        context.id = directory;
        
        return context;
    };
});
