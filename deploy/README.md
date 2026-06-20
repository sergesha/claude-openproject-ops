# deploy/ — external access for self-hosted OpenProject

`scripts/setup.sh` brings OpenProject up bound to **localhost only** (`127.0.0.1:8080`) — safe
by default. This directory holds what's needed to expose it on the public internet, mirroring
the host's existing pattern for `*.example.com` (nginx + certbot/Let's Encrypt).

## How external access works

The OpenProject Docker stack is **not** exposed directly. A host-level **nginx** reverse
proxy terminates TLS for each `<name>.example.com` subdomain and forwards to a
local port — the standard pattern for serving multiple self-hosted apps behind one host.

```
browser ──HTTPS──> nginx (:443, host)  ──HTTP──> 127.0.0.1:8080 ──> OpenProject proxy (Caddy) ──> web
        openproject.example.com          (compose port mapping)
```

## Why the claude-openproject-ops agent can't do this itself

Two capabilities sit outside the agent's unprivileged user account:

1. **DNS** — creating `openproject.example.com → YOUR_SERVER_IP` is done at the
   domain's DNS provider.
2. **root** — `/etc/nginx`, `certbot`, and `systemctl reload nginx` require sudo, which this
   user does not have.

So this directory ships a ready-to-run config + commands for an operator with those rights.

## Steps (operator with DNS + root)

1. **DNS:** add `openproject.example.com` A `→ YOUR_SERVER_IP`
   (AAAA if IPv6). Verify: `getent hosts openproject.example.com`.
2. **Point OpenProject at the public hostname + HTTPS** (no root needed — the agent can do
   this part):
   ```bash
   OP_HOST=openproject.example.com OP_HTTPS=true bash scripts/setup.sh
   ```
   (Keeps the localhost bind; nginx reaches it on 127.0.0.1:8080.)
3. **Change the default admin password** before the box is publicly reachable.
4. **Install the nginx vhost (root):**
   ```bash
   cp deploy/nginx/openproject.example.com.conf /etc/nginx/sites-available/openproject
   ln -s /etc/nginx/sites-available/openproject /etc/nginx/sites-enabled/openproject
   nginx -t && systemctl reload nginx
   certbot --nginx -d openproject.example.com
   ```
5. **Verify:** `curl -I https://openproject.example.com/login` → 200 + the sign-in page.

## Alternative: SSH tunnel (no DNS, no root, nothing to install)

For private/admin access without exposing anything:
```bash
ssh -L 8080:127.0.0.1:8080 youruser@YOUR_SERVER_IP
# then browse http://localhost:8080
```

## Optional: expose the port directly (NOT recommended without TLS)

`OP_PORT=0.0.0.0:8080 OP_HOST=YOUR_SERVER_IP:8080 bash scripts/setup.sh` publishes the
container port on all interfaces — plaintext HTTP, default creds risk. Use only behind a
trusted network; prefer the nginx + TLS path above.
