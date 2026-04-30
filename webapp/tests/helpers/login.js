/**
 * Login Helper - Reusable login function
 */
const fixtures = require('../fixtures');

/**
 * Login to PIM
 * @param {import('@playwright/test').Page} page - Playwright page object
 * @param {Object} credentials - Optional custom credentials
 * @returns {Promise<void>}
 */
async function login(page, credentials = null) {
    const creds = credentials || fixtures.credentials.valid;
    
    await page.goto(`${fixtures.urls.base}${fixtures.urls.login}`, {
        waitUntil: 'networkidle',
        timeout: 30000
    });
    
    await page.fill(fixtures.selectors.login.username, creds.username);
    await page.fill(fixtures.selectors.login.password, creds.password);
    await page.click(fixtures.selectors.login.submit);
    
    await page.waitForLoadState('networkidle', { timeout: 30000 });
    // Wait for SPA to render
    await page.waitForTimeout(5000);
}

/**
 * Check if user is logged in
 * @param {import('@playwright/test').Page} page
 * @returns {Promise<boolean>}
 */
async function isLoggedIn(page) {
    const url = page.url();
    return !url.includes('/user/login');
}

module.exports = {
    login,
    isLoggedIn
};
