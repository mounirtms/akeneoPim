const fs = require('fs');

console.log('╔════════════════════════════════════════════════════════════╗');
console.log('║       ANALYZING main.min.js for r.initialize ISSUE        ║');
console.log('╚════════════════════════════════════════════════════════════╝\n');

// Read the main.min.js file
const mainJs = fs.readFileSync('/home/pim/public_html/public/dist/main.min.js', 'utf8');

console.log('📋 Analysis 1: Extract error context (position 374152)...\n');
const errorPos = 374152;
const contextBefore = mainJs.substring(errorPos - 200, errorPos);
const contextAt = mainJs.substring(errorPos, errorPos + 100);
const contextAfter = mainJs.substring(errorPos + 100, errorPos + 300);

console.log('Context BEFORE error position:');
console.log(contextBefore);
console.log('\n--- ERROR POSITION (374152) ---\n');
console.log('Context AT error position:');
console.log(contextAt);
console.log('\nContext AFTER error position:');
console.log(contextAfter);

console.log('\n\n📋 Analysis 2: Find all r.initialize references...\n');
const rInitializeMatches = [...mainJs.matchAll(/r\.initialize/g)];
console.log(`Found ${rInitializeMatches.length} references to r.initialize`);
rInitializeMatches.forEach((match, idx) => {
    const pos = match.index;
    const context = mainJs.substring(pos - 50, pos + 150);
    console.log(`\nMatch ${idx + 1} at position ${pos}:`);
    console.log(context);
});

console.log('\n\n📋 Analysis 3: Find initialize() function calls...\n');
const initializeCalls = [...mainJs.matchAll(/\.initialize\(\)/g)];
console.log(`Found ${initializeCalls.length} .initialize() calls`);
initializeCalls.slice(0, 5).forEach((match, idx) => {
    const pos = match.index;
    const context = mainJs.substring(pos - 80, pos + 50);
    console.log(`\nCall ${idx + 1} at position ${pos}:`);
    console.log(context);
});

console.log('\n\n📋 Analysis 4: Search for extensions.json references...\n');
const extensionsJsonMatches = [...mainJs.matchAll(/extensions\.json/g)];
console.log(`Found ${extensionsJsonMatches.length} references to extensions.json`);
extensionsJsonMatches.forEach((match, idx) => {
    const pos = match.index;
    const context = mainJs.substring(pos - 100, pos + 200);
    console.log(`\nMatch ${idx + 1} at position ${pos}:`);
    console.log(context);
});

console.log('\n\n📋 Analysis 5: Look for t.initialize and other patterns...\n');
const tInitialize = [...mainJs.matchAll(/t\.initialize\(\)/g)];
console.log(`Found ${tInitialize.length} references to t.initialize()`);
if (tInitialize.length > 0) {
    const pos = tInitialize[0].index;
    const context = mainJs.substring(pos - 100, pos + 100);
    console.log('Context around t.initialize():');
    console.log(context);
}

console.log('\n\n📋 Analysis 6: Identify the promise chain causing the error...\n');
// The error context shows: e.when(e.get("/js/extensions.json"...), t.initialize(), r.initialize()).then(...)
// This is a jQuery.when() with 3 promises
const whenPattern = /e\.when\(e\.get\("\/js\/extensions\.json"[^)]+\),\s*t\.initialize\(\),\s*r\.initialize\(\)\)/g;
const whenMatches = [...mainJs.matchAll(whenPattern)];
console.log(`Found ${whenMatches.length} matching promise patterns`);
whenMatches.forEach((match, idx) => {
    const pos = match.index;
    const context = mainJs.substring(pos - 50, pos + 300);
    console.log(`\nPromise chain ${idx + 1} at position ${pos}:`);
    console.log(context);
});

console.log('\n\n📋 Analysis 7: Find where r is defined...\n');
// Look for common patterns like: var r = ..., const r = ..., let r = ...
const rDefinitions = [...mainJs.matchAll(/[,;{(]r=/g)];
console.log(`Found ${rDefinitions.length} possible r definitions (showing first 10)`);
rDefinitions.slice(0, 10).forEach((match, idx) => {
    const pos = match.index;
    const context = mainJs.substring(pos, pos + 150);
    console.log(`\nDefinition ${idx + 1} at position ${pos}:`);
    console.log(context);
});

console.log('\n\n✅ Analysis complete!\n');
