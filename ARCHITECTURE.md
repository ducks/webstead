# Webstead Architecture

**Your webstead away from home.**

A platform for makers, artists, and creators to build their own site with
built-in social features and federated conversations.

---

## Overview

Webstead is a multi-tenant Rails application that gives each user their own
subdomain (or custom domain) with:

1. **Personal site** - Portfolio/blog with templates (static feel)
2. **ActivityPub federation** - Content federates to the fediverse automatically
3. **Threaded conversations** - Forum-lite comments on content
4. **Real-time updates** - Pub/sub for live updates across the network

---

## Core Concepts

### Websteads (Tenants)
- Each user gets their own webstead at `username.webstead.dev`
- Can bring custom domain via CNAME (`artist.com`)
- Multi-tenant architecture (one Rails app serves all websteads)
- Isolated data per webstead

### Content
- Posts/pages that make up the webstead
- Markdown-based authoring
- Automatic ActivityPub federation when published
- Each piece of content can have threaded conversations

### Conversations (Forum-lite)
- Threaded comments on content
- Anyone with a fediverse account can participate
- Nested replies (Reddit/HN style)
- ActivityPub `inReplyTo` for federation

### Federation (ActivityPub)
- Each webstead is an ActivityPub actor
- Content publishes as ActivityPub objects (Articles/Notes)
- Follows/followers from Mastodon, other fediverse apps
- Replies federate back as conversations

---

## Technology Stack

### Backend
- **Ruby on Rails** - Multi-tenant web application
- **PostgreSQL** - Database with tenant isolation
- **ActionCable/Turbo** - Real-time updates within app

### Frontend
- **Hotwire/Turbo** - Modern reactive UI without heavy JS
- **Tailwind CSS** - Styling
- **Mobile-first** - Responsive, native-friendly design

### Federation
- **ActivityPub** - W3C standard for federation
- **Webfinger** - User discovery (username@webstead.dev)
- **HTTP Signatures** - Request authentication

### Infrastructure
- **Hosted at Discourse** (to start) or fly.io/render for simplicity
- **Redis** - Caching, job queues (Sidekiq)
- **Object storage** - S3 for images/media

---

## Data Model (Draft)

### Core Tables

**websteads**
- `id`
- `subdomain` (unique, used for routing)
- `custom_domain` (optional)
- `owner_id` (references users)
- `activitypub_handle` (e.g., @username@webstead.dev)
- `activitypub_inbox_url`
- `activitypub_outbox_url`
- `private_key` (for HTTP signatures)
- `public_key`
- `created_at`, `updated_at`

**users**
- `id`
- `email`
- `username`
- `password_digest`
- `webstead_id` (which webstead they own/manage)
- `created_at`, `updated_at`

**posts**
- `id`
- `webstead_id` (tenant isolation)
- `title`
- `slug`
- `body` (markdown)
- `published_at` (null = draft)
- `activitypub_object_id` (URL of the ActivityPub object)
- `allow_comments` (boolean)
- `created_at`, `updated_at`

**comments**
- `id`
- `post_id`
- `parent_id` (null for top-level, references another comment for threading)
- `author_id` (local user) or `activitypub_actor_id` (federated user)
- `body` (markdown)
- `activitypub_object_id` (if federated reply)
- `depth` (calculated, for limiting nesting)
- `created_at`, `updated_at`

**federated_actors** (cache of remote ActivityPub actors)
- `id`
- `activitypub_id` (their actor URL)
- `handle` (e.g., @user@mastodon.social)
- `display_name`
- `avatar_url`
- `inbox_url`
- `public_key`
- `last_fetched_at`
- `created_at`, `updated_at`

---

## Multi-Tenancy Strategy

### Subdomain Routing
- Middleware identifies tenant by `request.subdomain`
- Sets `Current.webstead` for request scope
- All queries automatically scoped to current webstead

### Tenant Isolation
- All tenant-scoped models use `acts_as_tenant` or similar
- `default_scope { where(webstead_id: Current.webstead.id) }`
- Prevents data leakage between websteads

### Custom Domains
- DNS CNAME points `artist.com` → `username.webstead.dev`
- Lookup `custom_domain` in database to identify tenant
- SSL via Let's Encrypt wildcard cert + custom cert per domain

---

## ActivityPub Integration

### Actor Setup (Per Webstead)
- Each webstead is an ActivityPub `Person` or `Service` actor
- Webfinger at `/.well-known/webfinger?resource=acct:username@webstead.dev`
- Actor object at `/users/username` (JSON-LD)
- Inbox at `/users/username/inbox` (receives activities)
- Outbox at `/users/username/outbox` (publishes activities)

### Publishing Content
1. User publishes a post
2. Create ActivityPub `Article` or `Note` object
3. Wrap in `Create` activity
4. Send to followers' inboxes (HTTP POST with signature)
5. Store `activitypub_object_id` on post

### Receiving Comments
1. Remote user replies on Mastodon/etc
2. Their server sends `Create` activity to webstead inbox
3. Verify HTTP signature
4. Extract `inReplyTo` (references original post)
5. Create comment record, link to post
6. Display in conversation thread

### Following/Followers
- Accept `Follow` activities in inbox
- Track followers (another table: `follows`)
- Send published content to all followers

---

## Comment Threading

### Adjacency List (Simple Start)
- `comments.parent_id` references another comment
- Recursive query to fetch entire thread
- Limit depth (e.g., 10 levels) to prevent infinite nesting

### Rendering Strategy
- Fetch all comments for post in one query
- Build tree structure in Ruby (or use `ancestry` gem)
- Render nested `<div>` structure with indentation
- Client-side collapse/expand for deep threads

### Performance Considerations
- Eager load `author` and `activitypub_actor`
- Cache rendered threads (Russian doll caching)
- Paginate top-level comments if thousands exist

---

## Real-Time Updates (Future)

### Pub/Sub Options
1. **ActionCable** (Rails native) - WebSockets for live updates within app
2. **Turbo Streams** - Server-sent events for reactive UI
3. **Deno Deploy pub/sub** (future) - Federated real-time layer across instances

### Use Cases
- New comment appears without refresh
- Follower count updates live
- Notifications for mentions/replies

---

## MVP Feature Set

### Phase 1: Core Platform
- [ ] Multi-tenant Rails app with subdomain routing
- [ ] User signup and webstead creation
- [ ] Basic post creation (markdown editor)
- [ ] Simple template (one design to start)
- [ ] Publish/unpublish posts

### Phase 2: Federation
- [ ] ActivityPub actor setup per webstead
- [ ] Webfinger discovery
- [ ] Publish posts as ActivityPub objects
- [ ] Accept follows from fediverse
- [ ] Send new posts to followers

### Phase 3: Conversations
- [ ] Comment system (local users only)
- [ ] Threaded replies (parent_id structure)
- [ ] Receive ActivityPub replies as comments
- [ ] Display federated + local comments together

### Phase 4: Polish
- [ ] Custom domains support
- [ ] Multiple templates
- [ ] Media uploads (images)
- [ ] Mobile-optimized UI
- [ ] Admin dashboard for webstead owners

---

## Open Questions

1. **Comment threading depth** - Cap at 10 levels? Collapse deep threads?
2. **Moderation** - How do webstead owners moderate federated comments?
3. **Spam prevention** - Rate limiting, blocklists for federated actors?
4. **Templates** - Static HTML/CSS or configurable via UI?
5. **Monetization** - Free tier + paid for custom domains? Or fully free?
6. **Discoverability** - Directory of websteads? Explore page?
7. **Migration** - Import from existing blogs (WordPress, Ghost)?

---

## Related Projects / Inspiration

- **Micro.blog** - Federated microblogging, similar philosophy
- **WriteFreely** - Minimalist federated writing platform
- **Mastodon** - ActivityPub reference implementation
- **Discourse** - Forum patterns, user management
- **Ghost** - Clean publishing platform
- **Tumblr** - Multi-tenant personal sites (before federation)

---

## Next Steps

1. Validate architecture with Rails prototype
2. Build minimal ActivityPub integration (publish one post)
3. Test federation with Mastodon instance
4. Design first template
5. Deploy MVP to Discourse infrastructure or fly.io
