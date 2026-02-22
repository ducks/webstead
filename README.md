# Webstead

Your webstead away from home.

Federated personal site platform with built-in ActivityPub and threaded
conversations. Not a forum, not a blog platform, but your own corner of the web
that speaks ActivityPub and has threaded discussions built-in.

## Status

Early development. Currently implementing core features (5 of 22 steps
complete).

## Features

### Implemented

**Multi-tenant Architecture**
- Each user gets `username.webstead.dev` (or custom domain)
- Subdomain routing with tenant isolation
- Row-level security with Current pattern
- TenantScoped concern for automatic scoping

**Webstead Model**
- Subdomain validation (3-63 chars, alphanumeric + hyphens)
- Custom domain support with DNS format validation
- Reserved subdomain protection (www, api, admin, etc.)
- JSONB settings column with GIN index
- One webstead per user

**Post Model**
- Draft/published/scheduled workflow
- `publish!`, `unpublish!` methods
- Scopes: draft, published, scheduled, recent
- Status helpers: `published?`, `draft?`, `scheduled?`
- Title required (1-300 chars)
- Body required for published posts
- Automatic webstead_id assignment

**Comment Model**
- Threaded via parent_id
- Supports federated actors
- Tenant-scoped

### Planned

- ActivityPub federation (outbox, publisher, federation jobs)
- Webfinger endpoint for discovery
- Markdown rendering
- Threading UI
- Authentication and webstead creation flow
- Production deployment with wildcard DNS

## Tech Stack

- Rails 8.1
- PostgreSQL 16
- Hotwire (Turbo + Stimulus)
- Tailwind CSS
- Ruby 3.3

## Development

### Setup

```bash
nix-shell
bundle install
rails db:create
rails db:migrate
```

### Running

```bash
rails server
```

### Tests

```bash
rails test
```

## Architecture

See `ARCHITECTURE.md` for detailed design decisions and implementation roadmap.

## Implementation

This project is being built using finna (multi-model AI debate and
implementation tool). Each step is debated by Claude, Codex, and Gemini, then
implemented and committed to a feature branch.

Progress: 5 of 22 steps complete
- Step 1: rails-app-setup
- Step 2: webstead-model
- Step 3: subdomain-routing
- Step 4: row-level-security
- Step 5: post-model

## License

MIT
