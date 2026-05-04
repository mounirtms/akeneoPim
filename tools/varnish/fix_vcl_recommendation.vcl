// Recommended VCL snippets: adjust probes and device detection
// Probe with explicit Host and X-Forwarded-Proto headers
backend prod {
  .host = "205.134.249.177";
  .port = "80";
  .probe = {
    .url = "/.well-known/acme-challenge/health";
    .timeout = 2s;
    .interval = 5s;
    .window = 5;
    .threshold = 3;
    .request = "GET /.well-known/acme-challenge/health HTTP/1.1\r\nHost: pim.technostationery.com\r\nX-Forwarded-Proto: https\r\nConnection: close\r\n\r\n";
  }
}

// Device detection: tablet before mobile
sub vcl_recv {
  if (req.http.User-Agent) {
    if (req.http.User-Agent ~ "(?i)tablet|ipad|playbook|silk") {
      set req.http.X-Device = "tablet";
    } elsif (req.http.User-Agent ~ "(?i)mobile|iphone|ipod|android.*mobile|blackberry|bb10") {
      set req.http.X-Device = "mobile";
    } else {
      set req.http.X-Device = "desktop";
    }
  }
  // Ensure X-Device preserved for vcl_hash
}

// In vcl_hash include req.http.X-Device and req.http.X-Forwarded-Proto
sub vcl_hash {
  if (req.http.host) { hash_data(req.http.host); }
  if (req.http.X-Device) { hash_data(req.http.X-Device); }
  if (req.http.X-Forwarded-Proto) { hash_data(req.http.X-Forwarded-Proto); }
}
