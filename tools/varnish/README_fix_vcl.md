This patch contains recommended Varnish VCL changes to:
- Use explicit probe .request including Host and X-Forwarded-Proto to match backend expectations
- Prioritise tablet detection before mobile to avoid misclassification
- Include X-Device and X-Forwarded-Proto in vcl_hash for proper cache key segmentation

Apply to /etc/varnish/<active>.vcl, test with `varnishd -C -f <file>` and reload with `systemctl reload varnish`.
