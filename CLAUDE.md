# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

CIViC (civic-v2): a community-curated knowledgebase of clinical interpretations of cancer variants. A Rails 8 backend exposes a **single GraphQL endpoint** (`POST /api/graphql`) consumed by an Angular 20 frontend. The same API is public (GraphiQL at `/api/graphiql`).

Monorepo layout: `server/` (Rails), `client/` (Angular). Most work happens in one or the other; changes that cross the boundary almost always go through the GraphQL schema.

## Commands

### Backend (`cd server`)
- Setup: `bundle install`, then `rails db:create db:schema:load`
- Run: `rails s` (port 3000)
- **Tests (Minitest, not RSpec):** `bundle exec rails test`. Single file: `bundle exec rails test test/graphql/mutations/add_comment_test.rb`. Single test: append `:42` (line number) or `-n test_name`. Tests need Postgres + Elasticsearch running; set `RAILS_ENV=test`.
- Lint/format: `bin/rubocop -a` (autocorrect). CI runs `bin/rubocop -f github`.
- Security scan: `bin/brakeman --no-pager`. To triage a warning into `config/brakeman.ignore`: `bin/brakeman -I`.
- CI uses Ruby **4.0.1** (README's "Ruby >= 3.3" is stale).

### Frontend (`cd client`)
- Setup: `yarn install`
- Run: `yarn start` (port 4200, HMR; proxies API calls to `:3000` per `proxy.config.json`)
- Build: `yarn build` (production config). CI's "frontend tests" job is just `yarn build` — Karma (`ng test`) is not run in CI.
- Lint: `yarn lint` (ESLint via `@angular-eslint`)
- **Regenerate GraphQL types: `yarn generate-apollo`** (or `:start` to watch). Run this after any change to the server schema or to a client `.gql` document.
- Icons: SVGs in `src/assets/icons/` are compiled to TS constants via `yarn generate-icons`.

## GraphQL is the contract between the two apps

1. Server schema is defined in code under `server/app/graphql/` (`types/`, `resolvers/`, `mutations/`, `loaders/`).
2. `bundle exec rake graphql:schema:dump` (defined in `server/lib/tasks/graphql.rake` via `GraphQL::RakeTask`) writes the SDL + introspection JSON directly into `client/src/app/generated/` (`server.model.graphql`, `server.schema.json`).
3. Client components/services define queries, mutations, and fragments in `*.gql` files colocated with the component.
4. `yarn generate-apollo` reads `client/.graphqlrc.yml`, combines the server schema with client-only schemas in `src/app/graphql/schemas/`, and generates `src/app/generated/civic.apollo.ts` (typed apollo-angular services), possible-types, and helpers.

Everything in `client/src/app/generated/` is generated — never edit by hand.

Resolvers for paginated list/browse endpoints use `search_object_graphql` (`resolvers/browse_*.rb`) backed by Postgres materialized views (`scenic` gem, `server/app/models/materialized_views/`). N+1 avoidance is via `graphql-batch` loaders.

## The curation / moderation model (core domain concept)

CIViC content (variants, genes, evidence items, assertions, molecular profiles, etc.) is **community-editable with editor review**. The mechanism is spread across concerns in `server/app/models/concerns/`:

- **`Moderated`** — mixed into editable records. Adds `revisions` / `open_revisions` (status `new`/`accepted`/`rejected`/`superseded`). A proposed edit creates a `Revision` per changed field, grouped into a `RevisionSet`. Editors accept/reject; acceptance applies the change.
- **`ModeratedField`** — marks which fields participate in revisions.
- **`WithAudits`** (`audited` gem) — immutable change history, separate from revisions.
- **`WithActivities`** / `Activity` subclasses (`*_activity.rb` models) — the user-facing event feed; nearly every mutation produces a typed Activity record. `Event` is the older/parallel mechanism still referenced in `Moderated`.
- **`Commentable`**, **`Flaggable`**, **`Subscribable`** — comments (with `@mention` parsing in `Actions::ProcessCommentBody` / `ExtractMentions`), flagging for editor attention, and email/on-site notifications.

Business logic for mutations lives in plain Ruby service objects under **`server/app/models/actions/`** (e.g. `Actions::SuggestRevisionSet`, `Actions::AcceptRevisions`, `Actions::SubmitEvidenceItem`), included via `Actions::Transactional`. GraphQL mutation classes in `server/app/graphql/mutations/` are thin wrappers that call these.

### Feature / Variant polymorphism

A `Feature` uses Rails `delegated_type :feature_instance` over `Features::Gene`, `Features::Factor`, `Features::Fusion`, `Features::Region` (each includes the `IsFeatureInstance` concern, which delegates missing methods back to `feature`). Each feature type has a matching variant subtype under `server/app/models/variants/`. `MolecularProfile` combines one or more variants and is what evidence/assertions actually attach to.

## Client structure

- `components/` — presentational + container components, grouped by domain (`variants/`, `evidence/`, `assertions/`, …). Each domain typically has `*.query.ts` / `.gql` pairs.
- `views/` — routed page-level components (routing in `app-routing.module.ts`, lazy-loaded modules per domain).
- `forms/` — curation forms built on **ngx-formly** + **ng-zorro-antd** (`ng-zorro` is the UI kit throughout). Form field configs, custom field types, and cross-field state live here; this is the most intricate part of the client.
- `core/services/` — app-wide services (viewer/auth, network, etc.).
- State: Apollo cache is the primary store; `@ngrx/component` for reactive template helpers, no ngrx store.

## Auth

OmniAuth (GitHub / Google / ORCID) → Rails session cookie. GraphQL requests from the same origin carry the CSRF cookie and are authenticated; requests without `X-XSRF-TOKEN` are treated as external API access with a null session (see `GraphqlController#from_external_domain`). API keys (`generate_api_key` mutation) support programmatic access.

Background jobs: **Sidekiq** (+ `sidekiq-cron`), admin at `/jobs`. Admin UI: **Trestle** under `server/app/admin/`. Error dashboard: `solid_errors` at `/errors`.

## Conventions

- **Every PR needs exactly one release-notes label:** `bugfix`, `housekeeping`, `new-feature`, `enhancement`, `dependencies`, or `ignore-for-release` (CI enforces).
- `git config blame.ignoreRevsFile .git-blame-ignore-revs` to skip the bulk rubocop/prettier reformat commits.
- Deploys are Capistrano via GitHub Actions: push to `staging` branch → staging; `release` branch / published release → production + docs (spectaql, `docs/config.yml`).
- `server/public/` frontend bundles are committed by an automated CI job (`build_frontend.yml`) — don't hand-edit or commit them.
- Spell-check (codespell) runs in CI; config in `.codespellrc`.
