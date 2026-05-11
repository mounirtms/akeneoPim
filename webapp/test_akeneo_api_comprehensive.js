const { chromium } = require('playwright');

class AkeneoAPITester {
  constructor() {
    this.baseUrl = 'https://pim.technostationery.com';
    this.clientId = '3_4jr9m44ntl44ggg4cgkcsccgwscsgo44s4wg0ccc48w8gc0kkk';
    this.clientSecret = '2myx2ccqwsowcko0k04woocgo4w0wk08gk8gkkgc0cwww88o44';
    this.username = 'admin';
    this.password = 'Admin1234!';
    this.accessToken = null;
    this.results = {
      passed: [],
      failed: [],
      warnings: []
    };
  }

  async authenticate() {
    console.log('🔐 Authenticating...');
    const response = await fetch(`${this.baseUrl}/api/oauth/v1/token`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        grant_type: 'password',
        client_id: this.clientId,
        client_secret: this.clientSecret,
        username: this.username,
        password: this.password
      })
    });

    const data = await response.json();
    
    if (data.access_token) {
      this.accessToken = data.access_token;
      this.results.passed.push('Authentication successful');
      console.log('✅ Authentication successful');
      return true;
    } else {
      this.results.failed.push('Authentication failed');
      console.error('❌ Authentication failed:', data);
      return false;
    }
  }

  async testEndpoint(name, endpoint, expectedFields = []) {
    console.log(`\n📡 Testing: ${name}`);
    console.log(`   Endpoint: ${endpoint}`);
    
    try {
      const response = await fetch(`${this.baseUrl}${endpoint}`, {
        headers: {
          'Authorization': `Bearer ${this.accessToken}`,
          'Content-Type': 'application/json'
        }
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const data = await response.json();
      
      // Check for embedded items structure
      if (data._embedded && data._embedded.items) {
        const itemCount = data._embedded.items.length;
        console.log(`   ✅ Response OK - ${itemCount} items found`);
        
        // Validate expected fields in first item
        if (itemCount > 0 && expectedFields.length > 0) {
          const firstItem = data._embedded.items[0];
          const missingFields = expectedFields.filter(field => !(field in firstItem));
          
          if (missingFields.length > 0) {
            this.results.warnings.push(`${name}: Missing fields - ${missingFields.join(', ')}`);
            console.log(`   ⚠️  Missing fields: ${missingFields.join(', ')}`);
          } else {
            console.log(`   ✅ All expected fields present`);
          }
        }
        
        this.results.passed.push(`${name}: ${itemCount} items`);
        return { success: true, count: itemCount, data: data._embedded.items };
      } else if (Array.isArray(data)) {
        console.log(`   ✅ Response OK - ${data.length} items found`);
        this.results.passed.push(`${name}: ${data.length} items`);
        return { success: true, count: data.length, data };
      } else {
        console.log(`   ✅ Response OK - Single item`);
        this.results.passed.push(`${name}: Single item`);
        return { success: true, count: 1, data };
      }
    } catch (error) {
      console.error(`   ❌ Failed: ${error.message}`);
      this.results.failed.push(`${name}: ${error.message}`);
      return { success: false, error: error.message };
    }
  }

  async testProductDetails(identifier) {
    console.log(`\n🔍 Testing Product Details: ${identifier}`);
    
    try {
      const response = await fetch(`${this.baseUrl}/api/rest/v1/products/${encodeURIComponent(identifier)}`, {
        headers: {
          'Authorization': `Bearer ${this.accessToken}`,
          'Content-Type': 'application/json'
        }
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }

      const product = await response.json();
      
      console.log(`   ✅ Product found`);
      console.log(`      - Identifier: ${product.identifier}`);
      console.log(`      - Family: ${product.family}`);
      console.log(`      - Enabled: ${product.enabled}`);
      console.log(`      - Categories: ${product.categories ? product.categories.length : 0}`);
      console.log(`      - Values: ${product.values ? Object.keys(product.values).length : 0} attributes`);
      
      this.results.passed.push(`Product details for ${identifier}`);
      return { success: true, product };
    } catch (error) {
      console.error(`   ❌ Failed: ${error.message}`);
      this.results.failed.push(`Product details for ${identifier}: ${error.message}`);
      return { success: false, error: error.message };
    }
  }

  async runAllTests() {
    console.log('═══════════════════════════════════════════');
    console.log('   AKENEO PIM API COMPREHENSIVE TEST SUITE');
    console.log('═══════════════════════════════════════════\n');
    console.log(`📅 Started: ${new Date().toISOString()}\n`);

    // Authenticate
    const authSuccess = await this.authenticate();
    if (!authSuccess) {
      console.log('\n❌ Cannot proceed without authentication');
      return this.printSummary();
    }

    // Test core endpoints
    console.log('\n━━━ CORE ENDPOINTS ━━━');
    
    const productsResult = await this.testEndpoint(
      'Products List',
      '/api/rest/v1/products?limit=10',
      ['identifier', 'family', 'enabled', 'categories']
    );

    await this.testEndpoint(
      'Families',
      '/api/rest/v1/families',
      ['code', 'attributes', 'attribute_as_label']
    );

    await this.testEndpoint(
      'Attributes',
      '/api/rest/v1/attributes?limit=50',
      ['code', 'type', 'group', 'scopable', 'localizable']
    );

    await this.testEndpoint(
      'Categories',
      '/api/rest/v1/categories',
      ['code', 'parent', 'labels']
    );

    await this.testEndpoint(
      'Channels',
      '/api/rest/v1/channels',
      ['code', 'currencies', 'locales']
    );

    await this.testEndpoint(
      'Locales',
      '/api/rest/v1/locales',
      ['code', 'enabled']
    );

    // Test product details
    if (productsResult.success && productsResult.data && productsResult.data.length > 0) {
      console.log('\n━━━ PRODUCT DETAILS ━━━');
      const testIdentifiers = productsResult.data.slice(0, 3).map(p => p.identifier);
      
      for (const identifier of testIdentifiers) {
        await this.testProductDetails(identifier);
      }
    }

    // Test attribute groups
    console.log('\n━━━ ADDITIONAL ENDPOINTS ━━━');
    
    await this.testEndpoint(
      'Attribute Groups',
      '/api/rest/v1/attribute-groups',
      ['code', 'attributes', 'labels']
    );

    await this.testEndpoint(
      'Association Types',
      '/api/rest/v1/association-types',
      ['code', 'labels']
    );

    // Print summary
    this.printSummary();
  }

  printSummary() {
    console.log('\n═══════════════════════════════════════════');
    console.log('              TEST SUMMARY');
    console.log('═══════════════════════════════════════════\n');
    
    console.log(`✅ Passed: ${this.results.passed.length}`);
    this.results.passed.forEach(test => console.log(`   - ${test}`));
    
    if (this.results.warnings.length > 0) {
      console.log(`\n⚠️  Warnings: ${this.results.warnings.length}`);
      this.results.warnings.forEach(warning => console.log(`   - ${warning}`));
    }
    
    if (this.results.failed.length > 0) {
      console.log(`\n❌ Failed: ${this.results.failed.length}`);
      this.results.failed.forEach(test => console.log(`   - ${test}`));
    }

    const totalTests = this.results.passed.length + this.results.failed.length;
    const passRate = totalTests > 0 ? (this.results.passed.length / totalTests * 100).toFixed(1) : 0;
    
    console.log('\n───────────────────────────────────────────');
    console.log(`Total Tests: ${totalTests}`);
    console.log(`Pass Rate: ${passRate}%`);
    console.log(`Status: ${this.results.failed.length === 0 ? '✅ ALL PASSED' : '⚠️ SOME FAILURES'}`);
    console.log('───────────────────────────────────────────\n');
    
    console.log(`📅 Completed: ${new Date().toISOString()}\n`);
  }
}

// Run tests
(async () => {
  const tester = new AkeneoAPITester();
  await tester.runAllTests();
})();
