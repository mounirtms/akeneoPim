const { chromium } = require('playwright');

async function checkHTMLSource() {
    console.log('🔍 Checking actual HTML source being served...\n');
    
    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({ ignoreHTTPSErrors: true });
    const page = await context.newPage();
    
    try {
        await page.goto('https://pim.technostationery.com/user/login', {
            waitUntil: 'domcontentloaded',
            timeout: 30000
        });
        
        await page.fill('input[name="_username"]', 'mounir');
        await page.fill('input[name="_password"]', '2026');
        await page.click('button[type="submit"]');
        await page.waitForTimeout(3000);
        
        const html = await page.content();
        
        // Check for our cache buster
        console.log('Cache Buster Check:');
        const cacheBusters = [
            '20260508_213900',
            '20260509_015000',
            '20260509_000000',
            '20260508_194139'
        ];
        
        for (const cb of cacheBusters) {
            if (html.includes(cb)) {
                console.log(`  ✅ Found: ${cb}`);
            }
        }
        
        // Check for patch file reference
        console.log('\nPatch File Reference:');
        if (html.includes('r-initialize-patch.js')) {
            console.log('  ✅ r-initialize-patch.js reference found in HTML');
        } else {
            console.log('  ❌ r-initialize-patch.js reference NOT found in HTML');
        }
        
        // Check for patch script content
        console.log('\nPatch Script Content:');
        if (html.includes('[Akeneo Patch]')) {
            console.log('  ✅ Patch script content found');
        } else {
            console.log('  ❌ Patch script content NOT found');
        }
        
        // Get a snippet around script tags
        const scriptSection = html.match(/require\.min\.js[\s\S]{0,500}/);
        if (scriptSection) {
            console.log('\nHTML around RequireJS load:');
            console.log(scriptSection[0].substring(0, 400));
        }
        
    } catch (error) {
        console.error('Error:', error.message);
    } finally {
        await browser.close();
    }
}

checkHTMLSource().catch(console.error);
