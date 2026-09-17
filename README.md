# Methods Research Lab — website

Source for <https://lab.methods-research.org>, a single-page site for the
Methods Research Lab.

Built with [Quarto](https://quarto.org). Quarto is the only build dependency:
no Python, no R, no Node, no front-end framework. The page content comes from
three YAML files, so adding a project or a person does not mean touching layout
code.

## Repository contents

| Path | What it is |
| --- | --- |
| `index.qmd` | The whole site — one page |
| `data/projects.yml` | Current and planned projects |
| `data/people.yml` | Members and collaborators |
| `data/related.yml` | External initiatives and resources |
| `_extensions/mrlab/lab/lab.lua` | Shortcodes that turn the YAML into HTML |
| `assets/lab.css` | All styling |
| `assets/` | Site mark, favicon, social card, project logos |
| `_quarto.yml` | Site config, SEO and social metadata |
| `partials/title-block.html` | Empty on purpose — suppresses Quarto's title block |
| `CNAME` | Custom domain for GitHub Pages |
| `docs/` | Build output. Not committed; GitHub Actions builds it. |

## Preview and render

```bash
quarto preview     # live preview at http://localhost:4321
quarto render      # one-shot build into docs/
```

That is the whole build. There is nothing to install beyond Quarto itself.

## Deployment

Pushing to `main` triggers `.github/workflows/deploy.yml`, which renders the
site and publishes it to GitHub Pages. `docs/` is deliberately **not** committed,
so the published site can never drift from the sources.

One-time setup in the GitHub repository:

1. **Settings → Pages → Build and deployment → Source: GitHub Actions.**
2. **Settings → Pages → Custom domain:** `lab.methods-research.org`, then tick
   *Enforce HTTPS* once the certificate is issued.

### DNS

At the DNS provider for `methods-research.org`, add one record:

| Type | Name | Value | TTL |
| --- | --- | --- | --- |
| `CNAME` | `lab` | `<github-username>.github.io.` | 3600 |

The `CNAME` file in this repository holds the same hostname and is copied into
the build, so GitHub Pages keeps the custom domain across deployments.

If the Lab ever moves to an institutional site, point this DNS record at the new
host. The address stays ours either way.

## Editing the site

### Projects — `data/projects.yml`

```yaml
- id: example
  name: "EXAMPLE"
  order: 5
  status: current          # current | planning
  logo: "assets/projects/example.svg"   # optional
  logo-alt: "EXAMPLE logo"
  description: >-
    One or two plain sentences.
  website: "https://example.org"        # optional
  outputs: "https://example.org/papers" # optional
```

- **Reorder projects:** change `order`. Lowest number first, within its own
  section. The numbers need not be consecutive.
- **Move something from planning to current:** change `status: planning` to
  `status: current` and give it an `order` that puts it where you want. The page
  moves it between sections by itself.
- **Hide a button:** leave `website` or `outputs` empty. The button disappears
  rather than rendering a dead link.
- **No logo yet:** leave `logo` empty and the card shows a plain monogram tile
  instead of a stand-in logo.

### People — `data/people.yml`

Two lists, `members` and `collaborators`, both sorted by `order`.

Members carry `name`, `university`, `order`, and optionally `linkedin`,
`scholar` and `orcid`. A profile link left empty is simply not shown.
Collaborators carry only `name`, `university` and `order`.

No job titles and no photos, by design.

### Related initiatives — `data/related.yml`

`name`, `order`, `url`, `description`. These render more lightly than the
project cards so that nothing external can be mistaken for a Lab project. Keep
each description explicit about the relationship.

### Logos and assets

Everything lives in `assets/`, copied into this repository so the build never
depends on a sibling folder:

- `assets/logo.png` — the shared *methods research* mark, used as the site mark
- `assets/favicon.svg` — favicon
- `assets/social.jpg` — 1200×630 Open Graph preview
- `assets/projects/` — per-project marks

Prefer SVG where one exists. Give every logo real alt text via `logo-alt`.

### "Last updated"

The footer date is Quarto's native `date-modified: last-modified` in
`index.qmd`, formatted as `MMMM YYYY`. It is the modification time of
`index.qmd` at render time, which in CI is the time of the build. Deploying
updates it; nothing is edited by hand and there is no JavaScript involved.

## Conventions worth keeping

- Links to other sites need `{target="_blank" rel="noopener noreferrer"}`.
  Quarto's `link-external-newwindow` does not run under `minimal: true`, and the
  shortcodes already add these attributes themselves.
- No analytics, no tracking, no cookie banner, no news or blog section.
- The University of Basel appears as a textual affiliation only — no logo and no
  corporate branding.
