# Deploying ERA to production (self-hosted)

This documents the setup currently running at **eradb.org**, on a Mac Mini
running Colima (Docker) at home, exposed with a Cloudflare Tunnel — no ports
opened on the router. If you're setting this up from scratch on a fresh
machine, follow it top to bottom. If you're the one who already has it
running, skip to [Day-to-day: deploying an update](#day-to-day-deploying-an-update).

## Architecture

A single Rails container serves both the GraphQL API and the pre-built
Angular SPA (baked into `server/public` at image-build time) — the same
single-origin topology CIViC itself deploys with, just without Capistrano.

```
Browser → Cloudflare (TLS, DNS) → cloudflared (on the host) → 127.0.0.1:3000
                                                                    │
                                                              docker-compose.prod.yml
                                                          ┌─────────┴─────────┐
                                                     server / sidekiq   db / redis / elasticsearch
```

- `server/Dockerfile.production` — multi-stage build: compiles the Angular
  client (stage 1, Node) → copies the result into `server/public` → final
  Ruby 4.0.1 image with `rails assets:precompile` already run.
- `docker-compose.prod.yml` — `db` (Postgres + pgvector), `redis`,
  `elasticsearch`, `server` (published **only** on `127.0.0.1:3000`, nothing
  exposed to the LAN/internet directly), `sidekiq`.
- Cloudflare Tunnel (`cloudflared`) runs natively on the host (not in Docker)
  and forwards `eradb.org` / `www.eradb.org` → `http://localhost:3000`.
  `RAILS_ENV=production` (not `headless` — headless disables OAuth login and
  GraphQL mutations, see `config/initializers/omniauth.rb` and
  `app/graphql/types/query_type.rb`; ERA needs those since it's meant to
  accept community contributions).

## One-time setup

### 1. Prerequisites on the host

- Docker (Colima or Docker Desktop)
- `cloudflared` (`brew install cloudflared`)
- The domain's DNS already on Cloudflare (nameservers pointed there)

### 2. Cloudflare Tunnel

If a tunnel doesn't already exist:
```bash
cloudflared tunnel login
cloudflared tunnel create era
```
This creates `~/.cloudflared/<tunnel-id>.json` and a `cert.pem` scoped to
whichever zone you picked during login — that scope matters for
`cloudflared tunnel route dns`, see the gotcha below.

**Important: find out which config file the running daemon actually reads.**
On this host there turned out to be *two* independent cloudflared setups: a
system-level LaunchDaemon (`/Library/LaunchDaemons/com.cloudflare.cloudflared.plist`,
reading `/etc/cloudflared/config.yml`, running as `root`) serving another
site already, and a separate user-level `brew services` LaunchAgent (reading
`~/.cloudflared/config.yml`) that turned out to be misconfigured and
inactive. Check which one is actually running before editing:
```bash
ps aux | grep cloudflared
```
Edit **that** config's `ingress` list — add the new hostname *above* the
final catch-all (`service: http_status:404`, order matters, first match
wins):
```yaml
ingress:
  - hostname: eradb.org
    service: http://localhost:3000
  - hostname: www.eradb.org
    service: http://localhost:3000
  - service: http_status:404   # must stay last
```
Then create the DNS records and restart:
```bash
cloudflared tunnel route dns <tunnel-id> eradb.org
cloudflared tunnel route dns <tunnel-id> www.eradb.org
# system daemon:
sudo launchctl unload /Library/LaunchDaemons/com.cloudflare.cloudflared.plist
sudo launchctl load /Library/LaunchDaemons/com.cloudflare.cloudflared.plist
# brew-managed:
brew services restart cloudflared
```

**Gotcha:** `cloudflared tunnel route dns` silently creates the record under
the *wrong* zone if the tunnel's `cert.pem` was authorized for a different
zone than the hostname you're routing (e.g. cert scoped to `other-domain.org`,
routing `eradb.org` → creates `eradb.org.other-domain.org`, which resolves to
nothing useful). If `dig <hostname>` doesn't resolve after `route dns`,
create the CNAME manually instead: Cloudflare dashboard → the domain's zone →
DNS → Add record → `CNAME`, name `@` (and another for `www`), target
`<tunnel-id>.cfargotunnel.com`, **Proxied** (orange cloud — required, this is
what makes a CNAME at the zone apex work at all).

Verify:
```bash
curl -s -o /dev/null -w "%{http_code}\n" https://eradb.org/
```

### 3. Cloudflare dashboard settings

- SSL/TLS → Overview → encryption mode `Full` (or leave "Automatic SSL/TLS",
  which resolves to `Full` on its own — either is fine).
- SSL/TLS → Edge Certificates → **Always Use HTTPS**: on. (Without this,
  `http://` requests are served in the clear instead of redirecting.)

### 4. OAuth apps

Each provider you want working needs its own app, with the callback set to
`https://<host>/api/auth/<provider>/callback` — register it once per hostname
you actually use (both `eradb.org` **and** `www.eradb.org` if both are live,
or GitHub will reject the login with "redirect_uri is not associated with
this application").

- GitHub: github.com/settings/developers → New OAuth App
- Google / ORCID: analogous, not yet set up for ERA

### 5. Secrets

```bash
cp .env.production.example .env.production   # gitignored, never commit it
```
Fill in:
- `SECRET_KEY_BASE` — `openssl rand -hex 64`
- `CIVIC_API_HMAC_KEY` — `openssl rand -hex 32`
- `POSTGRES_PASSWORD` — `openssl rand -hex 16`
- `CIVIC_GITHUB_KEY` / `CIVIC_GITHUB_SECRET` (and Google/ORCID once set up)

Leaving an OAuth key/secret blank is fine — that provider's login just won't
work, nothing crashes. What *would* crash the app: leaving these entirely
*unset* in an environment other than `headless` **only if** something calls
`Rails.application.credentials` as a fallback — this fork doesn't have the
original CIViC master key, so anything that still does that
(`config/database.yml`, `app/jobs/submit_analytics_event.rb` were both fixed
for this reason) will blow up on boot. If you add new code that reads
`Rails.application.credentials`, either don't, or make sure an `ENV[...] ||`
short-circuit always has the env var set in `.env.production`.

### 6. First deploy

```bash
git clone https://github.com/Vera-Genetics/ERA.git ~/era-app
cd ~/era-app
cp .env.production.example .env.production   # fill in secrets, see above
docker compose -f docker-compose.prod.yml --env-file .env.production up -d --build
```

First boot creates and migrates the database automatically
(`server/bin/docker-entrypoint` runs `bin/rails db:prepare`).

### 7. Make yourself admin

Log in once via the web UI first (GitHub/Google/ORCID button) so your `User`
row exists, then:
```bash
docker compose -f docker-compose.prod.yml --env-file .env.production exec server \
  bin/rails runner "puts User.pluck(:id, :username, :email).inspect"
```
Find your exact `username` in that output (don't guess it — GitHub's display
name and actual handle can differ, and CIViC's `default_username` has a bug
where it can suffix `_1` to itself even with no real collision — cosmetic
only, harmless), then:
```bash
docker compose -f docker-compose.prod.yml --env-file .env.production exec server \
  bin/rails runner "User.find_by(username: 'YOUR_USERNAME').make_admin!"
```

## Day-to-day: deploying an update

```bash
cd ~/era-app
git pull
docker compose -f docker-compose.prod.yml --env-file .env.production up -d --build
```

Backend-only changes (Ruby, routes, etc.) don't rebuild the Angular client —
`server/Dockerfile.production`'s client-build stage only needs an empty
`server/public` directory, not the rest of the server tree, so its Docker
cache is unaffected by backend edits. Only changes under `client/` trigger a
`yarn build` rerun.

Check it came up healthy:
```bash
docker compose -f docker-compose.prod.yml --env-file .env.production ps
curl -s http://localhost:3000/api/status
docker compose -f docker-compose.prod.yml --env-file .env.production logs server --tail 80
```

**Copy-pasting multi-line commands into a remote zsh session over SSH from a
Windows terminal has repeatedly corrupted heredocs and quoted strings on this
setup** (a stray indent on a heredoc's closing `EOF`, a lost quote splitting
`puts X` into `puts` + `X` silently). When something you paste hangs at a
`heredoc>` or `dquote>` prompt, `Ctrl+C` out and prefer short single-quoted
one-liners, or `nano` a file and run that instead of piping a heredoc.

## Known quirks / already-fixed footguns

These were real bugs hit getting this deployment working; documented in case
they resurface (e.g. after a `git revert`, or for anyone reading the commit
history):

- **`RAILS_ENV=headless` disables login and mutations.** Use `production`.
- **`config/database.yml`'s `production`/`staging` blocks referenced
  `Rails.application.credentials`** (the original CIViC master key, which
  this fork doesn't have) — fixed to rely on `DATABASE_URL` /
  `DATABASE_HOST`/`USERNAME`/`PASSWORD` env vars instead.
- **`config/puma/production.rb` and `headless.rb` were Capistrano deploy
  artifacts** hardcoded to a unix socket + `chdir` into
  `/var/www/civic/current` — crashed every boot in a container. Rewritten to
  bind TCP via `PORT`/`-p`, like `development.rb` already did.
- **`server/bin/docker-entrypoint`'s executable bit kept getting lost**
  across Windows/macOS checkouts of this repo. `Dockerfile.production` now
  `chmod +x`s it explicitly at build time instead of trusting git's file
  mode.
- **No nginx in front means Rails itself must serve the SPA for every
  route**, not just `/`. `config/routes.rb` has a catch-all
  (`get "*path", to: "static#index"`) for this — it must stay the *last*
  route, and must exclude `/api`, `/jobs`, `/errors`, `/chats`, `/rails`
  (Active Storage/Action Text engine routes — profile image uploads silently
  "did nothing" before this exclusion was added) and `/cable` (Action Cable).
- **`StaticController#index` needs an explicit action.** Without one, Rails
  renders the convention view `app/views/static/index.html.erb` — which in
  this codebase was a tiny pre-Angular login-status stub ("Welcome, X! Sign
  Out"), not the actual app. It's been removed; `index` now explicitly
  `render file: Rails.root.join("public", "index.html")`.
- **The Docker classic (non-BuildKit) builder mis-resolves an
  `ARG`-before-`FROM` across stages**, failing with `invalid reference
  format`. `Dockerfile.production` hardcodes the Ruby version in its `FROM`
  line instead. Installing `docker-buildx` avoids needing this workaround.
- **Ruby 4.0 removed `benchmark` from default gems**; `mini_magick` (via
  Active Storage's image analyzer) needs it without declaring the dependency.
  Added `gem "benchmark"` to the `Gemfile`.

## Backups

The `era-production_db-data` Docker volume on the Mac Mini is, right now,
the *only* copy of anything curated. There is no automated backup yet — set
one up (a scheduled `pg_dump` copied off-box) before there's real data worth
losing.
