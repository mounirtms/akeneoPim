const { chromium } = require('playwright');
const fs = require('fs').promises;

class AkeneoDataValidator {
  constructor() {
    this.baseUrl = 'https://pim.technostationery.com';
    this.clientId = '3_4jr9m44ntl44ggg4cgkcsccgwscsgo44s4wg0ccc48w8gc0kkk';
    this.clientSecret = '2myx2ccqwsowcko0k04woocgo4w0wk08gk8gkkgc0cwww88o44';
    this.username = 'admin';
    this.password = 'Admin1234!';
    this.accessToken = null;
    this.report = {
      timestamp: new Date().toISOString(),
      totalProducts: 0,
      validProducts: 0,
      invalidProducts: 0,
      warnings: [],
      errors: [],
      summary: {}
    };
  }

  async authenticate() {
    const response = await fetch(`${this.baseUrl}/api/oauth/v1/token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'password',
        client_id: this.clientId,
        client_secret: this.clientSecret,
        username: this.username,
        password: this.password
      })
    });

    const data = await response.json();
    this.accessToken = data.access_token;
    return !!this.accessToken;
  }

  async fetchProducts(limit = 100) {
    console.log(`\n📥 Fetching ${limit} products for validation...`);
    
    const response = await fetch(
      `${this.baseUrl}/api/rest/v1/products?limit=${limit}`,
      {
        headers: {
          'Authorization': `Bearer ${this.accessToken}`,
          'Content-Type': 'application/json'
        }
      }
    );

    const data = await response.json();
    return data._embedded.items;
  }

  async fetchProductDetails(identifier) {
    const response = await fetch(
      `${this.baseUrl}/api/rest/v1/products/${encodeURIComponent(identifier)}`,
      {
        headers: {
          'Authorization': `Bearer ${this.accessToken}`,
          'Content-Type': 'application/json'
        }
      }
    );

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    return await response.json();
  }

  validateProduct(product) {
    const issues = [];
    
    // Required fields validation
    if (!product.identifier || product.identifier.trim() === '') {
      issues.push({ field: 'identifier', message: 'Missing or empty SKU' });
    }
    
    if (!product.family) {
      issues.push({ field: 'family', message: 'Missing family' });
    }
    
    if (typeof product.enabled !== 'boolean') {
      issues.push({ field: 'enabled', message: 'Missing enabled status' });
    }
    
    // Categories validation
    if (!product.categories || !Array.isArray(product.categories)) {
      issues.push({ field: 'categories', message: 'Missing or invalid categories' });
    } else if (product.categories.length === 0) {
      issues.push({ field: 'categories', message: 'No categories assigned', severity: 'warning' });
    }
    
    // Values validation
    if (!product.values || typeof product.values !== 'object') {
      issues.push({ field: 'values', message: 'Missing values object' });
    }
    
    return {
      valid: issues.filter(i => i.severity !== 'warning').length === 0,
      issues
    };
  }

  analyzeProductValues(product) {
    if (!product.values) return { attributeCount: 0, hasImages: false, hasPrice: false };
    
    const values = product.values;
    const attributeCount = Object.keys(values).length;
    const hasImages = !!(values.image || values.small_image || values.thumbnail);
    const hasPrice = !!values.price;
    const hasName = !!values.name;
    const hasDescription = !!values.description;
    
    return {
      attributeCount,
      hasImages,
      hasPrice,
      hasName,
      hasDescription,
      attributes: Object.keys(values)
    };
  }

  async runValidation(sampleSize = 50) {
    console.log('═══════════════════════════════════════════');
    console.log('   AKENEO DATA VALIDATION & ANALYSIS');
    console.log('═══════════════════════════════════════════\n');
    console.log(`📅 Started: ${this.report.timestamp}\n`);

    // Authenticate
    console.log('🔐 Authenticating...');
    const authSuccess = await this.authenticate();
    if (!authSuccess) {
      console.log('❌ Authentication failed');
      return;
    }
    console.log('✅ Authenticated successfully\n');

    // Fetch products
    const products = await this.fetchProducts(sampleSize);
    this.report.totalProducts = products.length;
    console.log(`✅ Fetched ${products.length} products\n`);

    // Validation statistics
    const stats = {
      withImages: 0,
      withPrice: 0,
      withName: 0,
      withDescription: 0,
      withCategories: 0,
      enabled: 0,
      disabled: 0,
      families: {},
      attributeCounts: []
    };

    console.log('🔍 Validating products...\n');
    
    for (let i = 0; i < products.length; i++) {
      const product = products[i];
      const progress = ((i + 1) / products.length * 100).toFixed(1);
      process.stdout.write(`\r   Progress: ${progress}% (${i + 1}/${products.length})`);
      
      // Validate product
      const validation = this.validateProduct(product);
      const analysis = this.analyzeProductValues(product);
      
      if (validation.valid) {
        this.report.validProducts++;
      } else {
        this.report.invalidProducts++;
        const errors = validation.issues.filter(i => i.severity !== 'warning');
        if (errors.length > 0) {
          this.report.errors.push({
            identifier: product.identifier,
            issues: errors
          });
        }
      }
      
      // Collect warnings
      const warnings = validation.issues.filter(i => i.severity === 'warning');
      if (warnings.length > 0) {
        this.report.warnings.push({
          identifier: product.identifier,
          issues: warnings
        });
      }
      
      // Update statistics
      if (analysis.hasImages) stats.withImages++;
      if (analysis.hasPrice) stats.withPrice++;
      if (analysis.hasName) stats.withName++;
      if (analysis.hasDescription) stats.withDescription++;
      if (product.categories && product.categories.length > 0) stats.withCategories++;
      if (product.enabled) stats.enabled++;
      else stats.disabled++;
      
      // Track families
      if (product.family) {
        stats.families[product.family] = (stats.families[product.family] || 0) + 1;
      }
      
      stats.attributeCounts.push(analysis.attributeCount);
    }
    
    console.log('\n');
    
    // Calculate statistics
    const avgAttributes = stats.attributeCounts.length > 0 
      ? (stats.attributeCounts.reduce((a, b) => a + b, 0) / stats.attributeCounts.length).toFixed(1)
      : 0;
    
    this.report.summary = {
      withImages: stats.withImages,
      withPrice: stats.withPrice,
      withName: stats.withName,
      withDescription: stats.withDescription,
      withCategories: stats.withCategories,
      enabled: stats.enabled,
      disabled: stats.disabled,
      averageAttributes: avgAttributes,
      families: stats.families
    };
    
    // Print results
    this.printReport();
    
    // Save report to file
    await this.saveReport();
  }

  printReport() {
    console.log('\n═══════════════════════════════════════════');
    console.log('              VALIDATION REPORT');
    console.log('═══════════════════════════════════════════\n');
    
    // Summary
    console.log('📊 SUMMARY:');
    console.log(`   Total Products: ${this.report.totalProducts}`);
    console.log(`   Valid Products: ${this.report.validProducts} (${(this.report.validProducts/this.report.totalProducts*100).toFixed(1)}%)`);
    console.log(`   Invalid Products: ${this.report.invalidProducts} (${(this.report.invalidProducts/this.report.totalProducts*100).toFixed(1)}%)`);
    console.log(`   Warnings: ${this.report.warnings.length}`);
    
    // Data completeness
    console.log('\n📈 DATA COMPLETENESS:');
    const s = this.report.summary;
    console.log(`   Products with Images: ${s.withImages}/${this.report.totalProducts} (${(s.withImages/this.report.totalProducts*100).toFixed(1)}%)`);
    console.log(`   Products with Price: ${s.withPrice}/${this.report.totalProducts} (${(s.withPrice/this.report.totalProducts*100).toFixed(1)}%)`);
    console.log(`   Products with Name: ${s.withName}/${this.report.totalProducts} (${(s.withName/this.report.totalProducts*100).toFixed(1)}%)`);
    console.log(`   Products with Description: ${s.withDescription}/${this.report.totalProducts} (${(s.withDescription/this.report.totalProducts*100).toFixed(1)}%)`);
    console.log(`   Products with Categories: ${s.withCategories}/${this.report.totalProducts} (${(s.withCategories/this.report.totalProducts*100).toFixed(1)}%)`);
    console.log(`   Average Attributes per Product: ${s.averageAttributes}`);
    
    // Status distribution
    console.log('\n📌 STATUS DISTRIBUTION:');
    console.log(`   Enabled: ${s.enabled} (${(s.enabled/this.report.totalProducts*100).toFixed(1)}%)`);
    console.log(`   Disabled: ${s.disabled} (${(s.disabled/this.report.totalProducts*100).toFixed(1)}%)`);
    
    // Family distribution
    console.log('\n👥 FAMILY DISTRIBUTION:');
    const sortedFamilies = Object.entries(s.families).sort((a, b) => b[1] - a[1]);
    sortedFamilies.slice(0, 10).forEach(([family, count]) => {
      console.log(`   ${family}: ${count} products (${(count/this.report.totalProducts*100).toFixed(1)}%)`);
    });
    
    // Errors
    if (this.report.errors.length > 0) {
      console.log('\n❌ ERRORS (showing first 10):');
      this.report.errors.slice(0, 10).forEach(error => {
        console.log(`   ${error.identifier}:`);
        error.issues.forEach(issue => {
          console.log(`      - ${issue.field}: ${issue.message}`);
        });
      });
      if (this.report.errors.length > 10) {
        console.log(`   ... and ${this.report.errors.length - 10} more errors`);
      }
    }
    
    // Warnings
    if (this.report.warnings.length > 0) {
      console.log('\n⚠️  WARNINGS (showing first 10):');
      this.report.warnings.slice(0, 10).forEach(warning => {
        console.log(`   ${warning.identifier}:`);
        warning.issues.forEach(issue => {
          console.log(`      - ${issue.field}: ${issue.message}`);
        });
      });
      if (this.report.warnings.length > 10) {
        console.log(`   ... and ${this.report.warnings.length - 10} more warnings`);
      }
    }
    
    // Recommendations
    console.log('\n💡 RECOMMENDATIONS:');
    if (s.withImages / this.report.totalProducts < 0.9) {
      console.log('   ⚠️  Less than 90% of products have images. Consider adding images for better presentation.');
    }
    if (s.withPrice / this.report.totalProducts < 1.0) {
      console.log('   ⚠️  Some products are missing prices. This will cause sync errors.');
    }
    if (s.withName / this.report.totalProducts < 1.0) {
      console.log('   ⚠️  Some products are missing names. This is a required field for Magento.');
    }
    if (s.withCategories / this.report.totalProducts < 0.95) {
      console.log('   ⚠️  Some products have no categories. Consider assigning default categories.');
    }
    
    // Sync readiness
    console.log('\n🎯 SYNC READINESS:');
    const readinessScore = (
      (s.withPrice / this.report.totalProducts) * 0.3 +
      (s.withName / this.report.totalProducts) * 0.3 +
      (s.withCategories / this.report.totalProducts) * 0.2 +
      (s.withImages / this.report.totalProducts) * 0.2
    ) * 100;
    
    console.log(`   Overall Readiness Score: ${readinessScore.toFixed(1)}%`);
    
    if (readinessScore >= 90) {
      console.log('   ✅ Products are ready for Magento sync');
    } else if (readinessScore >= 75) {
      console.log('   ⚠️  Products are mostly ready, but some improvements recommended');
    } else {
      console.log('   ❌ Products need significant improvements before sync');
    }
    
    console.log('\n═══════════════════════════════════════════');
    console.log(`📅 Completed: ${new Date().toISOString()}\n`);
  }

  async saveReport() {
    const filename = `validation_report_${Date.now()}.json`;
    await fs.writeFile(filename, JSON.stringify(this.report, null, 2));
    console.log(`💾 Report saved to: ${filename}\n`);
  }
}

// Run validation
(async () => {
  const validator = new AkeneoDataValidator();
  await validator.runValidation(50);
})();
