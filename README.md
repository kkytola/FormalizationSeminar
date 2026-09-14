# Web page for Helsinki-Aalto formalized mathematics seminar

 * https://kkytola.github.io/FormalizationSeminar/

Weekly seminar's website, written in [Lean](https://lean-lang.org) using
[Verso](https://verso.lean-lang.org/) and published to GitHub Pages.


## Adding a talk

Open `SeminarSite/Data/SeminarTalkData.lean` and add an entry. Only the speaker and the date are
required:

```lean
{ speaker := "David Hilbert"
  date := Date.fromYearMonthDay 1900 8 8 },
```

Fill in the rest as it becomes known. A more detailed entry can look like:

```lean
{ speaker := { desc := "Ada Lovelace", link := "https://example.org/~lovelace" }
  affiliation := some { desc := "University of London"
                        link := "https://example.org/london/maths" }
  date := Date.fromYearMonthDay 1843 9 29
  title := some { desc := "Notes on the Analytical Engine"
                  link := "https://example.org/papers/note-g" }
  abstract := "What the Engine could have computed, and how we would say so today.\n\n\
    The second half discusses Note G."
  misc := [
    { desc := "Slides", link := "https://example.org/slides.pdf" },
    { desc := "Note: exceptionally at 16:15" },
    { desc := "Recording", link := "…", dontshow := some true }
  ] },
```

The speaker, the affiliation and the title are all `MiscItem`s — text plus an optional `link` plus
an optional `dontshow` — because that is exactly what each of them is. A bare string coerces to
one, so `speaker := "Ada Lovelace"` and `title := "Notes on the Analytical Engine"` are fine when
there is no link; write the record out when there is. (Lean's `{ … }` notation does not coerce
through `Option`, so the two optional fields need an explicit `some` around the record.)

- `abstract` is plain text. A blank line (`\n\n`) starts a new paragraph; there is no markup.
- `misc` items render as a row of small links under the talk, or as plain notes when they have no
  `link`. `dontshow := some true` keeps an item in the file but off the site — useful for a
  recording link that is not public yet.
- `affiliation` is shown in brackets after the speaker's name.
- `dontshow := some true` works on all four: on `speaker` and `title` the entry falls back to
  "Speaker to be announced" / "Title to be announced", which is how you hold a date for an
  invitation that is agreed but not yet public; on `affiliation` and on a `misc` item it is simply
  omitted.
- A talk with a link but no title yet has no `title` record to hang it on — put it in `misc`
  instead, as `{ desc := "Preprint", link := "…" }`.
- An imprecise date is fine: `Date.fromYearMonth 2026 11` is "some time in November 2026", and
  `Date.fromYear 2025` is "some time in 2025". Such a talk stays under *Upcoming* until the end of
  the period it names.

Commit and push. The site rebuilds and redeploys on its own.

## Building it locally

Needs [elan](https://github.com/leanprover/elan), the Lean version manager; it installs the
toolchain named in `lean-toolchain` by itself.

```sh
lake build              # type-checks the talk data and every page
lake exe generate-site  # writes _site/
```

Then serve `_site/` over HTTP rather than opening the files directly — the pages use a `<base>`
element that `file://` URLs do not handle:

```sh
cd _site && python3 -m http.server
```

Both steps matter. `lake build` compiles the data and the page sources; `lake exe generate-site` is
what resolves cross-page links and renders the talk lists, and it exits non-zero if any of that
fails. The workflow runs both for the same reason.

### Previewing another day

The upcoming/past split comes from the clock. To see what the site will look like later:

```sh
SEMINAR_TODAY=2027-01-15 lake exe generate-site
```

## How the upcoming/past split works

Each of the two directives

```
:::upcomingSeminars
:::

:::pastSeminars
:::
```

expands into a Verso *component*, and a component is rendered while `generate-site` runs — not
while Lean compiles. So the date comparison happens at generation time, which has a consequence
worth knowing:

> **Re-running the workflow with no source change is enough to retire a finished talk.**

That is what the nightly `schedule:` in [`.github/workflows/pages.yml`](.github/workflows/pages.yml)
is for. Had the split been fixed while Lean compiled, a cached build would have re-emitted the old
split and the schedule would have achieved nothing.

Two details:

- **"Today" is UTC.** A site should not render differently depending on whether it was built on a
  runner or on a laptop. Talks are a day apart, so a few hours of offset never changes the split;
  the only visible effect is that a talk can stay listed as upcoming for a few hours after
  midnight local time.
- **A talk is upcoming for the whole of its last possible day**, so today's talk is still under
  *Upcoming* on the morning of the seminar rather than already in the archive.

## Layout

```
lakefile.toml                          the package: one dependency (Verso), one library, one exe
lean-toolchain                         the Lean version; must match the Verso tag in lakefile.toml
lake-manifest.json                     the exact commit of every dependency

Main.lean                              the HTML template, the list of pages and their URLs, main
SeminarSite.lean                       library root; imports everything, so `lake build` checks it

SeminarSite/
  Config.lean                          name, tagline, contact, footer — the strings on every page
  Date.lean                            the date type, parsing, formatting, and "today"
  Talk.lean                            the SeminarTalk structure and the upcoming/past queries
  Data/SeminarTalkData.lean            ← the talk database; the file you edit every week
  Render.lean                          the :::upcomingSeminars::: and :::pastSeminars::: directives
  Pages/Front.lean                     /
  Pages/PastTalks.lean                 /past-talks/
  Pages/PracticalInfo.lean             /practical-info/
  Pages/Organizers.lean                /organizers/

static_files/                          copied verbatim to /static/
  style.css                            the whole site's appearance
  favicon.svg

.github/workflows/pages.yml            build on every push and PR; publish on push, nightly, manual
```

## Customising

**Appearance.** All of it is in [`static_files/style.css`](static_files/style.css), which is copied
rather than compiled: edit it and re-run `lake exe generate-site`, no Lean rebuild. The talk
entries use the classes `.talk`, `.talk-when`, `.talk-speaker`, `.talk-title`, `.talk-abstract` and
`.talk-links`.

**The page frame** — header, navigation, footer, `<head>` — is the `theme` in
[`Main.lean`](Main.lean). Keep its URLs relative (`static/style.css`, not `/static/style.css`):
Verso emits a `<base>` pointing at the site root, so relative URLs work both locally and under the
`/<repo>/` prefix that GitHub Pages serves a project site from. Absolute paths would work locally
and 404 once published.

**The time and place.** `meetingTime`, `meetingRoom`, `meetingBuilding` and `meetingAddress` in
`Config.lean` are assembled into one phrase by the `{timeAndPlace}[]` role, so a change of room is
one edit rather than a hunt through the pages:

> The seminar meets **Fridays at 13:15–14:00** in **room U4062** of the **main building of
> University of Helsinki** (Fabianinkatu 33).

The role emits only the phrase, from the time up to the closing bracket — each page writes its own
sentence around it. `meetingTime` should read naturally after "the seminar meets". The building and
the address are optional and each takes its connecting words with it, so setting both to `none`
gives "… **Fridays at 13:15–14:00** in **room U4062**." with no dangling "of the" or empty
brackets.

**A new page** needs three things: a file under `SeminarSite/Pages/`, an `import` in
`SeminarSite.lean`, and an entry in the `seminarSite` declaration in `Main.lean`. The navigation
menu is generated from that declaration, so nothing else needs updating.

**Showing only the next few talks** — both directives take an optional count:

```
:::upcomingSeminars (count := 3)
:::
```

**What a talk entry looks like** is `talkHtml` in [`SeminarSite/Render.lean`](SeminarSite/Render.lean).

