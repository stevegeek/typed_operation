# Port TypedOperation docs site to jekyll-vitepress-theme

Date: 2026-05-26

## Goal

Convert the `website/` Jekyll site from the `just-the-docs` theme to
`jekyll-vitepress-theme` (v1.4.x), matching the structure used by the
[vident](https://github.com/stevegeek/vident/tree/main/website) docs site:
three content collections, VitePress-style hero homepage, `_data`-driven
navigation, and a `jekyll_vitepress` config block with emerald branding.

Scope: structural port **plus light content polish** (fix stale bits, tighten
page intros, ensure rendering under the new theme). No structural prose
rewrites.

## Decisions (confirmed)

- **Scope:** structural port + light content polish.
- **Page mapping:** by role (see below).
- **Brand accent:** emerald/green.
- **Deployment:** none added here — Cloudflare Pages already auto-deploys on
  push. `url` set to placeholder `https://typed-operation-gem.diaconou.com`.
- **Logo:** none; text site title `TypedOperation`.

## Target structure

```
website/
  _config.yml            # jekyll-vitepress-theme + collections + jekyll_vitepress block
  Gemfile                # drop just-the-docs; add theme + jekyll-sitemap
  index.md               # VitePress hero + features homepage
  _data/
    navigation.yml       # Introduction / Guides / Reference / Changelog
    sidebar.yml          # collection -> sidebar grouping
    social_links.yml     # GitHub link
  _introduction/
    getting-started.md   # nav_order 1
    similar-gems.md      # nav_order 2
  _guides/
    pipelines.md         # 1
    integrations.md      # 2
    instrumentation.md   # 3
    best-practices.md    # 4
  _reference/
    api.md               # 1
    examples.md          # 2
```

Removed: `docs/` (after moving its files), `404.html`, `.nojekyll`.

## `_config.yml`

Mirror vident's shape:

- `theme: jekyll-vitepress-theme`
- `plugins: [jekyll-vitepress-theme, jekyll-feed, jekyll-sitemap]`
- `markdown: kramdown`, `kramdown.input: GFM`, `syntax_highlighter: rouge`
- `permalink: pretty`
- `collections:` `introduction`, `guides`, `reference` — each `output: true`
  with permalink `/<name>/:path/`
- `defaults:` map each collection to `layout: default`
- `jekyll_vitepress:` block:
  - `branding.site_title: TypedOperation` (no logo)
  - `syntax.light_theme: github`, `syntax.dark_theme: github.dark`
  - `edit_link.pattern: https://github.com/stevegeek/typed_operation/edit/main/website/:path`
  - `footer.message` (MIT) + `footer.copyright` (Stephen Ierodiaconou)
  - `tokens` — emerald:
    - light: `--vp-c-brand-1: #059669`, `-2: #047857`, `-3: #065f46`
    - dark: `--vp-c-brand-1: #34d399`, `-2: #10b981`, `-3: #059669`
- `url: https://typed-operation-gem.diaconou.com`, `baseurl: ""`
- `github_username: stevegeek`, `github_repo: typed_operation`
- `exclude: [Gemfile, Gemfile.lock, vendor/, node_modules/, README.md]`

## `Gemfile`

```ruby
source "https://rubygems.org"
gem "jekyll", "~> 4.4"
gem "jekyll-vitepress-theme"
group :jekyll_plugins do
  gem "jekyll-feed", "~> 0.17"
  gem "jekyll-sitemap", "~> 1.4"
end
# platform shims kept (tzinfo, wdm, http_parser.rb)
```

## `_data` files

`navigation.yml` (top nav):
```yaml
- { title: Introduction, url: /introduction/getting-started/, collections: [introduction] }
- { title: Guides,       url: /guides/pipelines/,             collections: [guides] }
- { title: Reference,    url: /reference/api/,                collections: [reference] }
- { title: Changelog,    url: https://github.com/stevegeek/typed_operation/blob/main/CHANGELOG.md }
```

`sidebar.yml`:
```yaml
- { title: Introduction, collection: introduction }
- { title: Guides,       collection: guides }
- { title: Reference,    collection: reference }
```

`social_links.yml`:
```yaml
- { icon: github, url: https://github.com/stevegeek/typed_operation, label: TypedOperation on GitHub }
```

## Front-matter conversion (each moved page)

- Keep `title`; set per-collection `nav_order` (see structure).
- Remove `layout:` (set by `defaults`) and `permalink:` (set by collection).
- Remove `{: .no_toc }` markers and the `## Table of contents` + `{:toc}`
  blocks — the theme renders an automatic outline.
- Strip any `.fs-* / .fw-* / .text-delta` class annotations.
- Update cross-page links to new permalinks. Known: two `/api#...` links in
  `integrations.md` -> `/reference/api/#...`.

## Homepage (`index.md`)

`layout: home` with VitePress front matter:

- `hero`: name **TypedOperation**; text/tagline from README ("A Command
  pattern implementation for Ruby with typed parameters, partial application,
  and operation composition"); actions: "Get started" ->
  `/introduction/getting-started/`, "View on GitHub" -> repo.
- `features` (6 cards): typed parameters, partial application & currying,
  operation composition / pipelines, result types (built-in + Dry::Monads),
  Rails integration & generators, ActionPolicy authorization.
- Below front matter: short intro, a Quick Start code sample, install snippet,
  and a "Where to next" link list pointing at the new collection permalinks.

## Light content polish

While moving: fix stale references, tighten the one-line page intros, confirm
code fences and headings render cleanly under the new theme. No restructuring
of prose.

## Verification

- `cd website && bundle install`
- `bundle exec jekyll build` succeeds with no errors.
- `bundle exec jekyll serve` renders: home (hero + emerald accent), all three
  collections, top nav, and sidebar.
- Spot-check internal links resolve (no `/docs/...` leftovers).

## Out of scope

- Deployment config (Cloudflare already wired).
- Gem `README.md` doc-site links (separate file, not part of `website/`).
- Logo/illustration assets.
