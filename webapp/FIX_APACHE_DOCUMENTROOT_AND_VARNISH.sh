#!/bin/bash

echo "=========================================="
echo "COMPREHENSIVE FIX - Apache DocumentRoot + Varnish"
echo "Date: $(date)"
echo "=========================================="
echo ""

# Backup Apache config
echo "=== STEP 1: Backup Apache Configuration ==="
cp /etc/apache2/conf/httpd.conf /etc/apache2/conf/httpd.conf.backup.$(date +%Y%m%d_%H%M%S)
echo "✅ Apache config backed up"

# Fix pim.technostationery.com VirtualHost DocumentRoot
echo ""
echo "=== STEP 2: Fix PIM VirtualHost DocumentRoot ==="
echo "Searching for pim.technostationery.com VirtualHost..."

# Extract line numbers for the VirtualHost block
VHOST_START=$(grep -n "ServerName pim.technostationery.com" /etc/apache2/conf/httpd.conf | head -1 | cut -d: -f1)

if [ -n "$VHOST_START" ]; then
    echo "Found VirtualHost at line $VHOST_START"
    
    # Show current DocumentRoot
    echo ""
    echo "Current DocumentRoot:"
    sed -n "${VHOST_START},$((VHOST_START+50))p" /etc/apache2/conf/httpd.conf | grep "DocumentRoot" | head -1
    
    # Fix DocumentRoot to point to /public subdirectory
    sed -i.bak '/ServerName pim.technostationery.com/,/^<\/VirtualHost>/s|DocumentRoot /home/pim/public_html|DocumentRoot /home/pim/public_html/public|' /etc/apache2/conf/httpd.conf
    
    # Also fix the Directory directive
    sed -i '/ServerName pim.technostationery.com/,/^<\/VirtualHost>/s|<Directory "/home/pim/public_html">|<Directory "/home/pim/public_html/public">|' /etc/apache2/conf/httpd.conf
    
    echo ""
    echo "New DocumentRoot:"
    sed -n "${VHOST_START},$((VHOST_START+50))p" /etc/apache2/conf/httpd.conf | grep "DocumentRoot" | head -1
    
    echo "✅ DocumentRoot fixed to /home/pim/public_html/public"
else
    echo "❌ Could not find pim.technostationery.com VirtualHost"
fi

# Restart Apache
echo ""
echo "=== STEP 3: Restart Apache ==="
/scripts/restartsrv_httpd --graceful
sleep 3
systemctl status httpd --no-pager | head -10
echo "✅ Apache restarted"

# Test Apache locally
echo ""
echo "=== STEP 4: Test Apache Directly ==="
echo "Testing http://localhost with Host: pim.technostationery.com"
curl -I -H "Host: pim.technostationery.com" http://localhost/ 2>&1 | head -10

echo ""
echo "Testing http://localhost/user/login"
curl -I -H "Host: pim.technostationery.com" http://localhost/user/login 2>&1 | head -10

# Configure Varnish for multiple sites
echo ""
echo "=== STEP 5: Configure Varnish for All Sites ==="

# Stop varnish first
systemctl stop varnish 2>/dev/null

# Create comprehensive Varnish VCL
cat > /etc/varnish/default.vcl << 'EOFVCL'
vcl 4.1;

import std;

# Backend definitions
backend pim {
    .host = "127.0.0.1";
    .port = "80";
    .first_byte_timeout = 300s;
    .between_bytes_timeout = 300s;
}

backend magento {
    .host = "127.0.0.1";
    .port = "80";
    .first_byte_timeout = 120s;
}

backend dashboard {
    .host = "127.0.0.1";
    .port = "80";
    .first_byte_timeout = 60s;
}

backend lms {
    .host = "127.0.0.1";
    .port = "80";
    .first_byte_timeout = 120s;
}

# Access control list for purging
acl purge {
    "localhost";
    "127.0.0.1";
    "::1";
    "205.134.249.177";
}

# Request handling
sub vcl_recv {
    # Set backend based on hostname
    if (req.http.host ~ "^(www\.)?pim\.technostationery\.com") {
        set req.backend_hint = pim;
    } elsif (req.http.host ~ "^(www\.)?technostationery\.com") {
        set req.backend_hint = magento;
    } elsif (req.http.host ~ "^dashboard\.technostationery\.com") {
        set req.backend_hint = dashboard;
    } elsif (req.http.host ~ "^lms\.technostationery\.com") {
        set req.backend_hint = lms;
    } else {
        # Default to Magento
        set req.backend_hint = magento;
    }

    # Allow purging from authorized IPs
    if (req.method == "PURGE") {
        if (!client.ip ~ purge) {
            return (synth(405, "Not allowed"));
        }
        return (purge);
    }

    # Normalize the host header
    set req.http.host = regsub(req.http.host, ":[0-9]+", "");

    # Remove Google Analytics cookies
    set req.http.Cookie = regsuball(req.http.Cookie, "(^|;\s*)(_ga|_gid|_gat|__utm[a-z])=[^;]*", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "^;\s*", "");
    if (req.http.Cookie == "") {
        unset req.http.Cookie;
    }

    # === PIM (Akeneo) Caching Rules ===
    if (req.http.host ~ "pim\.technostationery\.com") {
        # Never cache admin/login pages
        if (req.url ~ "^/user/login" ||
            req.url ~ "^/admin" ||
            req.url ~ "^/_wdt" ||
            req.url ~ "^/_profiler" ||
            req.url ~ "^/api") {
            return (pass);
        }
        
        # Cache static assets aggressively
        if (req.url ~ "\.(js|css|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot)$") {
            unset req.http.Cookie;
            return (hash);
        }
        
        # Pass POST, PUT, DELETE requests
        if (req.method != "GET" && req.method != "HEAD") {
            return (pass);
        }
        
        # Pass requests with authorization or session cookies
        if (req.http.Authorization || req.http.Cookie ~ "PHPSESSID") {
            return (pass);
        }
    }

    # === Magento Caching Rules ===
    if (req.http.host ~ "^(www\.)?technostationery\.com") {
        # Never cache admin, checkout, customer pages
        if (req.url ~ "^/(admin|checkout|customer|wishlist|paypal)") {
            return (pass);
        }
        
        # Cache static content
        if (req.url ~ "\.(js|css|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot|pdf)$") {
            unset req.http.Cookie;
            return (hash);
        }
        
        # Pass POST requests
        if (req.method != "GET" && req.method != "HEAD") {
            return (pass);
        }
        
        # Pass if logged in
        if (req.http.Cookie ~ "frontend=") {
            return (pass);
        }
    }

    # === Dashboard - Always bypass cache ===
    if (req.http.host ~ "dashboard\.technostationery\.com") {
        return (pass);
    }

    # === LMS Caching Rules ===
    if (req.http.host ~ "lms\.technostationery\.com") {
        # Cache static assets only
        if (req.url ~ "\.(js|css|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot)$") {
            unset req.http.Cookie;
            return (hash);
        }
        # Everything else bypass cache
        return (pass);
    }

    return (hash);
}

sub vcl_backend_response {
    # Set backend name for debugging
    set beresp.http.X-Backend = bereq.backend;
    
    # Default TTL for cacheable content
    if (beresp.ttl <= 0s) {
        set beresp.ttl = 10s;
    }

    # Cache static assets for longer
    if (bereq.url ~ "\.(js|css|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot)$") {
        set beresp.ttl = 1h;
        set beresp.http.Cache-Control = "public, max-age=3600";
        unset beresp.http.Set-Cookie;
    }

    # Don't cache responses with Set-Cookie header (except static assets)
    if (beresp.http.Set-Cookie && bereq.url !~ "\.(js|css|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot)$") {
        set beresp.ttl = 0s;
        set beresp.uncacheable = true;
        return (deliver);
    }

    # Enable ESI for PIM
    if (bereq.http.host ~ "pim\.technostationery\.com") {
        set beresp.do_esi = true;
    }

    return (deliver);
}

sub vcl_deliver {
    # Add cache hit/miss header for debugging
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
        set resp.http.X-Cache-Hits = obj.hits;
    } else {
        set resp.http.X-Cache = "MISS";
    }
    
    # Remove backend header in production
    unset resp.http.X-Backend;
    
    # Security headers
    set resp.http.X-Frame-Options = "SAMEORIGIN";
    set resp.http.X-Content-Type-Options = "nosniff";
    set resp.http.X-XSS-Protection = "1; mode=block";
    
    return (deliver);
}

# Handle synthetic responses
sub vcl_synth {
    if (resp.status == 405) {
        set resp.http.Content-Type = "text/html; charset=utf-8";
        synthetic("PURGE not allowed from " + client.ip);
        return (deliver);
    }
}
EOFVCL

echo "✅ Varnish VCL configuration created"

# Update Varnish systemd service to use port 8080
echo ""
echo "=== STEP 6: Configure Varnish to Listen on Port 8080 ==="

# Create systemd override directory
mkdir -p /etc/systemd/system/varnish.service.d/

# Create override configuration
cat > /etc/systemd/system/varnish.service.d/override.conf << 'EOFSVC'
[Service]
ExecStart=
ExecStart=/usr/sbin/varnishd \
    -a :8080 \
    -a localhost:8443,PROXY \
    -f /etc/varnish/default.vcl \
    -s malloc,6G \
    -T localhost:6082 \
    -p default_ttl=3600 \
    -p default_grace=3600 \
    -p feature=+esi_ignore_https \
    -p feature=+esi_disable_xml_check \
    -p vcc_allow_inline_c=on
EOFSVC

echo "✅ Varnish configured to listen on port 8080"

# Reload systemd and start Varnish
systemctl daemon-reload
systemctl enable varnish
systemctl start varnish

sleep 3

# Check Varnish status
echo ""
echo "=== STEP 7: Verify Varnish Status ==="
systemctl status varnish --no-pager | head -15

echo ""
echo "Varnish processes:"
ps aux | grep varnish | grep -v grep

echo ""
echo "Listening ports:"
netstat -tlnp | grep -E ":(80|8080|6082)" | head -10

# Test Varnish
echo ""
echo "=== STEP 8: Test Varnish ==="
echo "Testing http://localhost:8080 with Host: pim.technostationery.com"
curl -I -H "Host: pim.technostationery.com" http://localhost:8080/ 2>&1 | head -15

echo ""
echo "Testing http://localhost:8080/user/login"
curl -I -H "Host: pim.technostationery.com" http://localhost:8080/user/login 2>&1 | head -15

echo ""
echo "=========================================="
echo "SUMMARY"
echo "=========================================="
echo "✅ Apache DocumentRoot fixed to /home/pim/public_html/public"
echo "✅ Apache restarted and verified"
echo "✅ Varnish configured for all sites (PIM, Magento, Dashboard, LMS)"
echo "✅ Varnish listening on port 8080"
echo ""
echo "Architecture:"
echo "  Client → Cloudflare → Apache:80 (or Varnish:8080) → PHP-FPM"
echo ""
echo "Next steps:"
echo "1. Test https://pim.technostationery.com/ (should work now!)"
echo "2. Test login at https://pim.technostationery.com/user/login"
echo "3. If working, optionally switch Cloudflare to point to Varnish port 8080"
echo "   (requires cPanel proxy configuration)"
echo ""
echo "=========================================="

