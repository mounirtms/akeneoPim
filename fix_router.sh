#!/bin/bash
# Fix router.js - remove incorrect module parameters from methods

echo "🔧 Fixing router.js method parameters"
echo "======================================"

file="public/bundles/pimui/js/router.js"

# Backup
cp "$file" "$file.bak2"

# Fix initialize function - should have no parameters
sed -i 's/initialize: function (module, )/initialize: function ()/' "$file"

# Fix index function - should have no parameters  
sed -i 's/index: function (module, )/index: function ()/' "$file"

# Fix defaultRoute - should only have path parameter
sed -i 's/defaultRoute: function (module, path)/defaultRoute: function (path)/' "$file"

# Fix notFound - should have no parameters
sed -i 's/notFound: function (module, )/notFound: function ()/' "$file"

# Fix handleError - should only have xhr parameter
sed -i 's/handleError: function (module, xhr)/handleError: function (xhr)/' "$file"

# Fix errorPage - should only have xhr parameter
sed -i 's/errorPage: function (module, xhr)/errorPage: function (xhr)/' "$file"

# Fix displayErrorPage - should have message and code parameters
sed -i 's/displayErrorPage: function (module, message, code)/displayErrorPage: function (message, code)/' "$file"

# Fix triggerStart - should only have route parameter
sed -i 's/triggerStart: function (module, route)/triggerStart: function (route)/' "$file"

# Fix triggerComplete - should only have route parameter
sed -i 's/triggerComplete: function (module, route)/triggerComplete: function (route)/' "$file"

# Fix showLoadingMask - should have no parameters
sed -i 's/showLoadingMask: function (module, )/showLoadingMask: function ()/' "$file"

# Fix hideLoadingMask - should have no parameters
sed -i 's/hideLoadingMask: function (module, )/hideLoadingMask: function ()/' "$file"

# Fix generate - should have no parameters in definition
sed -i 's/generate: function (module, )/generate: function ()/' "$file"

# Fix match - should have no parameters in definition
sed -i 's/match: function (module, )/match: function ()/' "$file"

# Fix redirect - should have fragment and options parameters
sed -i 's/redirect: function (module, fragment, options)/redirect: function (fragment, options)/' "$file"

# Fix redirectToRoute - should have route, routeParams, options parameters
sed -i 's/redirectToRoute: function (module, route, routeParams, options)/redirectToRoute: function (route, routeParams, options)/' "$file"

# Fix reloadPage - should have no parameters
sed -i 's/reloadPage: function (module, )/reloadPage: function ()/' "$file"

# Fix _processLinks - should have no parameters
sed -i 's/_processLinks: function (module, )/_processLinks: function ()/' "$file"

# Fix the _.each callback in _processLinks - should only have link parameter
sed -i 's/_.each(\$('\''a\[route\]'\''), function (module, link)/_.each($('\''a[route]'\''), function (link)/' "$file"

# Fix nested function callbacks - remove module parameter
sed -i 's/function (module, controller)/function (controller)/' "$file"
sed -i 's/function (module, )/function ()/' "$file"

echo "✅ Router.js fixed!"
echo ""
echo "Verifying..."
grep -c "function (module," "$file" && echo "⚠️  Still has 'function (module,' - manual check needed" || echo "✅ All 'function (module,' patterns removed"

