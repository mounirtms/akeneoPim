const { chromium } = require('playwright');

async function test() {
    console.log('🔍 Starting final verification test...\n');
    
    const browser = await chromium.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
    
    // Track errors
    const errors = [];
    page.on('pageerror', err => errors.push(err.message));
    
    try {
        // Test Mounir login
        console.log('Testing Mounir login...');
        await page.goto('https://pim.technostationery.com/user/login', { waitUntil: 'networkidle', timeout: 30000 });
        
        await page.fill('input[name="_username"]', 'mounir');
        await page.fill('input[name="_password"]', '2026');
        await page.click('button[type="submit"]');
        
        await page.waitForTimeout(10000); // Wait for dashboard
        
        const url = page.url();
        const title = await page.title();
        
        console.log(`  URL: ${url}`);
        console.log(`  Title: ${title}`);
        
        // Save screenshot
        await page.screenshot({ path: '/home/pim/public_html/webapp/final_test_mounir.png', fullPage: true });
        
        // Check what's on the page
        const bodyText = await page.textContent('body').catch(() => '');
        const hasLoadingText = bodyText.includes('Loading');
        const hasDashboard = !url.includes('/user/login');
        
        console.log(`  Has "Loading" text: ${hasLoadingText}`);
        console.log(`  Redirected from login: ${hasDashboard}`);
        console.log(`  JavaScript errors: ${errors.length}`);
        
        if (errors.length > 0) {
            console.log('\n  ⚠️  JavaScript Errors:');
            errors.forEach(err => console.log(`    - ${err}`));
        }
        
        // Check for specific elements
        const elements = {
            nav: await page.$('nav').then(e => !!e),
            header: await page.$('header').then(e => !!e),
            main: await page.$('main').then(e => !!e),
            loading: await page.$('.AknLoadingMask').then(e => !!e)
        };
        
        console.log('\n  Page Elements:');
        Object.entries(elements).forEach(([key, found]) => {
            console.log(`    ${found ? '✅' : '❌'} ${key}`);
        });
        
        // Get HTML structure
        const html = await page.content();
        const hasAkeneoClasses = html.includes('Akn');
        console.log(`\n  Has Akeneo CSS classes: ${hasAkeneoClasses}`);
        
        // Save HTML for debugging
        require('fs').writeFileSync('/home/pim/public_html/webapp/final_test_page.html', html);
        
        console.log('\n✅ Test complete');
        console.log('📄 Screenshot: final_test_mounir.png');
        console.log('📄 HTML saved: final_test_page.html');
        
    } catch (error) {
        console.error(`\n❌ Test failed: ${error.message}`);
    } finally {
        await browser.close();
    }
}

test();
