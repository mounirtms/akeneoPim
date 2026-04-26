#!/bin/bash
# Copy vendor JavaScript libraries to public/dist

echo "Copying vendor JavaScript libraries..."

# Create dist directory if it doesn't exist
mkdir -p public/dist

# Copy jQuery
cp node_modules/jquery/dist/jquery.min.js public/dist/
echo "✓ jQuery copied"

# Copy Underscore
cp node_modules/underscore/underscore-min.js public/dist/underscore.min.js
echo "✓ Underscore copied"

# Copy Backbone
cp node_modules/backbone/backbone-min.js public/dist/backbone.min.js
echo "✓ Backbone copied"

# Copy React
cp node_modules/react/umd/react.production.min.js public/dist/react.min.js
echo "✓ React copied"

# Copy React-DOM
cp node_modules/react-dom/umd/react-dom.production.min.js public/dist/react-dom.min.js
echo "✓ React-DOM copied"

# Create process polyfill
cat > public/dist/process-polyfill.js << 'POLYFILL'
// Process polyfill for browser
if (typeof process === 'undefined') {
  window.process = {
    env: {
      NODE_ENV: 'production'
    }
  };
}
POLYFILL
echo "✓ Process polyfill created"

# Set proper permissions
chmod 644 public/dist/*.min.js public/dist/process-polyfill.js
chown pim:pim public/dist/*.min.js public/dist/process-polyfill.js 2>/dev/null || true

echo ""
echo "All vendor libraries copied successfully!"
ls -lh public/dist/*.min.js public/dist/process-polyfill.js
