import VersoBlog
import SeminarSite

/-!
# The site generator

Three things live here: the HTML template every page is poured into (`theme`), the list of pages
and their URLs (`seminarSite`), and `main`.

Running `lake exe generate-site` writes the finished tree to `_site/`.
-/

open Verso Genre Blog Site Syntax
open SeminarSite

open Template in
/--
The contents of `<title>`: the page's own title, followed by the seminar's short name so that a
browser tab or a search result says which site it belongs to. The front page is the exception --
its title already *is* the seminar's name.
-/
def pageTitle (cfg : SeminarConfig) : TemplateM String := do
  let title ← param (α := String) "title"
  if title == cfg.name || title == cfg.shortName then
    return title
  return s!"{title} — {cfg.shortName}"

open Output Html Template Theme in
/--
The page template.

All URLs here are *relative*, with no leading `/`. Verso's `builtinHeader` emits a `<base href>`
pointing at the site root, so `static/style.css` resolves correctly from any depth -- and, unlike
`/static/style.css`, it also resolves when the site is served from a subdirectory, which is what
GitHub Pages does for a project site at `https://<user>.github.io/<repo>/`. Absolute paths would
work locally and 404 once published.

`Theme.default` supplies the templates this one does not override: the `<article>` wrapper around
each page, and the blog-post and category templates, which this site never reaches because it has
no blog section.
-/
def theme : Theme := { Theme.default with
  primaryTemplate := do
    let cfg := seminarConfig
    -- Both footer links are optional, so the row holding them is optional too: an
    -- empty `<p>` would still take up its margin under the copyright line.
    -- The binder types are written out: without them the `{{address}}` splice
    -- unifies the bound variable with `Html` before `Option String` can fix it.
    let contactLink : Option Html :=
      cfg.contactEmail.map fun (address : String) =>
        {{<a href=s!"mailto:{address}">{{address}}</a>}}
    let sourceLink : Option Html :=
      cfg.repoUrl.map fun (url : String) => {{<a href={{url}}>"Site source"</a>}}
    let footerLinks : Array Html := #[contactLink, sourceLink].filterMap id
    return {{
      <html lang="en">
        <head>
          <meta charset="utf-8"/>
          <meta name="viewport" content="width=device-width, initial-scale=1"/>
          <meta name="color-scheme" content="light dark"/>
          <title>{{ ← pageTitle cfg }}</title>
          <!--
            `builtinHeader` comes before anything with a URL in it: it carries the `<base href>`
            that the relative paths below are resolved against, as well as Verso's own styles and
            scripts. The site stylesheet comes after it, so that it can override them.
          -->
          {{← builtinHeader}}
          <link rel="icon" href="static/favicon.svg" type="image/svg+xml"/>
          <link rel="stylesheet" href="static/style.css"/>
        </head>
        <body>
          <header class="site-header">
            <div class="wrap">
              <a class="site-name" href=".">{{cfg.name}}</a>
              {{ if cfg.tagline.isEmpty then Html.empty
                 else {{<p class="site-tagline">{{cfg.tagline}}</p>}} }}
              {{← topNav (homeLink := some "Home")}}
            </div>
          </header>
          <main class="wrap">
            {{← param "content"}}
          </main>
          <footer class="site-footer">
            <div class="wrap">
              {{ if footerLinks.isEmpty then Html.empty
                 else {{<p class="footer-links">{{footerLinks}}</p>}} }}
              <p class="footer-copyright">{{cfg.copyright}}</p>
            </div>
          </footer>
        </body>
      </html>
    }}
  }
  -- The front page gets its own wrapper class, so that CSS can give its opening paragraph the
  -- standing-information treatment without affecting the other pages. `#[]` is the root path.
  |>.override #[] ⟨
    do return {{
      <article class="front-page">
        <h1>{{← param "title"}}</h1>
        {{← param "content"}}
      </article>
    }},
    id⟩

/--
The pages, and the URLs they are published at.

A page exists on the web only if it is listed here. Adding one means adding it in three places: a
file under `SeminarSite/Pages/`, an `import` in `SeminarSite.lean`, and a line here.

`static "static" ← "static_files"` copies that directory to `_site/static/`, which is what the
stylesheet and favicon references in `theme` point at. The source path is relative to the working
directory, so `generate-site` must be run from the repository root.
-/
def seminarSite : Site := site SeminarSite.Pages.Front /
  static "static" ← "static_files"
  "past-talks" SeminarSite.Pages.PastTalks
  "practical-info" SeminarSite.Pages.PracticalInfo
  "organizers" SeminarSite.Pages.Organizers

def main (args : List String) : IO UInt32 := do
  -- Reading the date up front does two things: it fixes one "today" for the whole run (see
  -- `SeminarSite.todayCached`), and it turns a malformed `SEMINAR_TODAY` into an error now rather
  -- than in the middle of generating a page.
  let today ← todayCached
  IO.println s!"Generating the site as of {today} \
    (set SEMINAR_TODAY=YYYY-MM-DD to preview another day)"

  -- An impossible date is a typo, and a typo in a date is otherwise invisible: the talk just never
  -- leaves the upcoming list. Warn, but generate anyway -- a wrong date should not take the site
  -- down.
  for problem in dateProblems seminarTalks do
    IO.eprintln s!"warning: {problem}"

  blogMain theme seminarSite (options := args)
