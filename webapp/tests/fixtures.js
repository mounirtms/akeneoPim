/**
 * Test Fixtures - Common test data and credentials
 */
module.exports = {
    // Credentials
    credentials: {
        valid: {
            username: 'testadmin',
            password: 'testpass'
        },
        invalid: {
            username: 'invalid_user',
            password: 'wrong_password'
        }
    },
    
    // Base URLs
    urls: {
        base: 'https://pim.technostationery.com',
        login: '/user/login',
        dashboard: '/',
        products: '/enrich/product/',
        categories: '/enrich/product-category-tree/',
        import: '/collect/import/',
        export: '/spread/export/',
        jobs: '/job',
        attributes: '/configuration/attribute/',
        attributeGroups: '/configuration/attribute-group/',
        families: '/configuration/family/',
        channels: '/configuration/channel/',
        locales: '/configuration/locale/'
    },
    
    // Expected data counts
    expected: {
        products: 9538,
        productModels: 418,
        images: 8605
    },
    
    // Selectors
    selectors: {
        login: {
            username: 'input[name="_username"]',
            password: 'input[name="_password"]',
            submit: 'button[type="submit"]'
        },
        dashboard: {
            title: 'h1, .AknTitle-title'
        },
        products: {
            grid: 'table, .datagrid, [class*="grid"]',
            rows: 'tr, .datagrid-row',
            images: 'img'
        }
    }
};
