# Webstead Production Deployment

This guide covers deploying Webstead to production using Kamal with wildcard DNS and SSL.

## Prerequisites

- Server with Docker installed
- Domain name (e.g., `webstead.dev`)
- DNS provider supporting wildcard records
- PostgreSQL database (self-hosted or managed)

## DNS Configuration

Configure your DNS to point wildcard subdomains to your server:

```
A    @                 YOUR_SERVER_IP
A    *.webstead.dev    YOUR_SERVER_IP
```

This allows `alice.webstead.dev`, `bob.webstead.dev`, etc. to all point to your server.

## Environment Setup

1. Copy the example secrets file:
```bash
cp .kamal/secrets-example .kamal/secrets
```

2. Edit `.kamal/secrets` with your actual values:
```bash
KAMAL_REGISTRY_PASSWORD=your_registry_password
RAILS_MASTER_KEY=your_master_key
SECRET_KEY_BASE=$(rails secret)
POSTGRES_PASSWORD=your_postgres_password
```

3. Update `config/deploy.yml`:
- Change `servers.web` to your server IP
- Configure registry settings
- Set PostgreSQL connection details
- Add your email for Let's Encrypt

## SSL with Let's Encrypt

Kamal includes Traefik for automatic SSL via Let's Encrypt. With the traefik configuration in `deploy.yml`:

- HTTP requests on port 80 redirect to HTTPS
- HTTPS certificates auto-renew
- Wildcard certificates require DNS-01 challenge (more complex setup)
- Alternatively, use HTTP-01 challenge with individual certs per subdomain

## Database Setup

Before first deploy, create the production database:

```bash
# SSH to your database server
createdb webstead_production
```

Or use a managed PostgreSQL service (Render, Neon, etc.).

## First Deployment

```bash
# Install Kamal
gem install kamal

# Set up server (installs Docker, creates directories)
kamal setup

# Deploy application
kamal deploy
```

## Subsequent Deployments

```bash
kamal deploy
```

## Running Migrations

```bash
kamal app exec 'bin/rails db:migrate'
```

## Useful Commands

```bash
# Open Rails console
kamal console

# View logs
kamal app logs -f

# SSH to server
kamal app exec --interactive --reuse bash

# Rollback deployment
kamal rollback

# Check app status
kamal app details
```

## Wildcard SSL Notes

For true wildcard SSL certificates (`*.webstead.dev`), you need:

1. DNS provider with API support (Cloudflare, Route53, etc.)
2. Configure Let's Encrypt DNS-01 challenge
3. Use Traefik plugins for your DNS provider

Alternatively, use HTTP-01 challenge and get individual certs for each subdomain as users sign up.

## Troubleshooting

**Subdomain routing not working:**
- Verify wildcard DNS record is set
- Check that `config.force_ssl = true` is set in `production.rb`
- Ensure Traefik is routing correctly

**SSL certificate errors:**
- Check Let's Encrypt rate limits
- Verify email in Traefik configuration
- Check Traefik logs: `kamal traefik logs`

**Database connection errors:**
- Verify `DB_HOST` environment variable
- Check PostgreSQL accepts connections from app server IP
- Verify credentials in `.kamal/secrets`

## Security Checklist

- [ ] `RAILS_MASTER_KEY` is set and secret
- [ ] `SECRET_KEY_BASE` is unique and secret
- [ ] PostgreSQL uses strong password
- [ ] Server firewall only allows ports 22, 80, 443
- [ ] SSH key-based authentication enabled
- [ ] Regular database backups configured
- [ ] Application monitoring set up

## Monitoring

Consider adding:
- Application performance monitoring (New Relic, Scout, etc.)
- Error tracking (Sentry, Honeybadger, etc.)
- Uptime monitoring (Pingdom, UptimeRobot, etc.)
- Log aggregation (Papertrail, Logtail, etc.)

## Scaling

When ready to scale:

1. **Add more web servers:**
   - Update `servers.web` in `deploy.yml`
   - Deploy with `kamal deploy`

2. **Separate job processing:**
   - Add `servers.job` to `deploy.yml`
   - Set `SOLID_QUEUE_IN_PUMA=false`

3. **Add database replicas:**
   - Configure read replicas in `database.yml`
   - Update connection pool settings

4. **Use external Redis:**
   - Configure for Action Cable and caching
   - Update `cable.yml` and `cache.yml`

## Production Readiness

Before going live:

- [ ] Run full test suite: `rails test:all`
- [ ] Check security with Brakeman: `brakeman`
- [ ] Review dependencies: `bundle audit`
- [ ] Test SSL configuration
- [ ] Verify subdomain routing works
- [ ] Test ActivityPub federation with real Mastodon instance
- [ ] Configure backups
- [ ] Set up monitoring and alerts
- [ ] Document runbooks for common issues
