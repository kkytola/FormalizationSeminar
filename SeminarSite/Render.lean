import VersoBlog
import SeminarSite.Config
import SeminarSite.Data.SeminarTalkData

/-!
# Rendering the talk lists

This file defines the two directives that the pages use:

```
:::upcomingSeminars
:::

:::pastSeminars
:::
```

Both take no contents and read everything they show from the single database in
`SeminarSite.Data.SeminarTalkData`. Each accepts one optional argument, `(count := n)`, which caps
how many talks are listed.

## Why these are components rather than plain directives

A directive is ordinarily expanded while the Lean file elaborates: it becomes, at compile time, the
document blocks it stands for. Doing the upcoming/past split there would bake it into the compiled
module -- and a compiled module is cached, so a rebuild a month later with no source change would
re-emit last month's split. The scheduled workflow whose whole job is to retire finished talks
would achieve nothing.

So each directive instead expands into a Verso *component*, and a component's `toHtml` runs when
`generate-site` runs. The clock is read there. Every run of the generator therefore produces a
correct split -- including a run triggered by nothing but the clock, with a fully warm Lake cache
and not a single source edit.

The cost is that these lists are built as HTML rather than as Verso blocks, so the fields cannot
contain Verso markup. They are plain `String`s in the database anyway.
-/

open Lean
open Verso Genre Blog
open Verso ArgParse Doc Elab
open Verso Output Html

namespace SeminarSite

/-! ## The seminar's regular time and place -/

/--
The seminar's regular slot, as an inline element:

> *Fridays at 13:15–14:00* in *room U4062* of the *main building of University of Helsinki*
> (Fabianinkatu 33)

The three named parts are bold, as they were when the phrase was written out by hand on each page.
The building and the address are optional, and each takes its own connecting words with it when it
is absent, rather than leaving a dangling "of the" or an empty pair of brackets.

Genre-polymorphic, so the phrase is not tied to the `Page` genre.
-/
def meetingPhrase {g : Genre} : Inline g := Id.run do
  let cfg := seminarConfig
  let strong (text : String) : Inline g := .bold #[.text text]
  let mut parts := #[strong cfg.meetingTime, .text " in ", strong cfg.meetingRoom]
  if let some building := cfg.meetingBuilding then
    parts := parts ++ #[.text " of the ", strong building]
  if let some address := cfg.meetingAddress then
    parts := parts ++ #[.text s!" ({address})"]
  -- One inline rather than an array: a bare `Inline.concat` in the role's quotation below
  -- would be ambiguous at each use site between Verso's and Lean's `Doc.Inline`.
  return .concat parts

/--
The seminar's time and place, from `seminarConfig`. Takes no arguments and no content, so that a
page can write the sentence around it:

```
The seminar meets {timeAndPlace}[].
```

Changing the room is then an edit to `SeminarSite/Config.lean`, not a hunt through the pages.
-/
-- A bare `@[role]` registers the role under this declaration's own name; the form with an
-- argument, as used by the talk-list directives below, names an existing constant instead.
@[role]
def timeAndPlace : RoleExpanderOf NoArgs
  | _, contents => do
    unless contents.isEmpty do
      logErrorAt (mkNullNode contents) "'timeAndPlace' takes no contents"
    ``(meetingPhrase)

/-! ## One consistent "today" per run -/

/--
The date the current generation run should treat as today, computed once.

Each directive would otherwise read the clock separately, and two reads either side of midnight
would disagree about which list a talk belongs to -- a talk could appear in both, or in neither.
Reading once also means `SEMINAR_TODAY` is validated once, up front.
-/
initialize todayRef : IO.Ref (Option Date) ← IO.mkRef none

/-- `Date.today`, memoised for the duration of this process. See `todayRef`. -/
def todayCached : IO Date := do
  if let some date ← todayRef.get then
    return date
  let date ← Date.today
  todayRef.set date
  return date

/-! ## Pieces of a talk entry -/

/--
A `MiscItem`'s text, as a link when it carries a URL.

Every piece of text on a talk that might be linked -- the speaker, the affiliation, the title, and
each of the `misc` extras -- is a `MiscItem`, so they all render through here.
-/
private def miscItemInline (item : MiscItem) : Html :=
  match item.link with
  | some url => {{ <a href={{url}}>{{item.desc}}</a> }}
  | none => .text true item.desc

/-- One `misc` item as a list entry. An item with no URL is a note, not a link. -/
private def miscItemHtml (item : MiscItem) : Html :=
  if item.link.isSome then {{ <li>{{miscItemInline item}}</li> }}
  else {{ <li class="talk-link-plain">{{miscItemInline item}}</li> }}

/-- Stands in for a `MiscItem` that is missing or marked `dontshow`. -/
private def tbaHtml (what : String) : Html :=
  {{ <span class="talk-tba">{{what}}</span> }}

/--
Plain text as paragraphs, splitting on blank lines.

Abstracts in the database are ordinary strings, so this is the only structure they can carry. A
long abstract written as one unbroken string still renders, just as a single paragraph.
-/
private def paragraphsHtml (text : String) : Html :=
  let paragraphs : List String :=
    text.splitOn "\n\n" |>.map (·.trimAscii.copy) |>.filter (!·.isEmpty)
  Html.fromList <| paragraphs.map fun p => {{ <p>{{Html.text true p}}</p> }}

/--
The speaker's name, linked to their page when the database has one.

A speaker marked `dontshow` is a date held for an invitation that cannot be announced yet, so the
entry says so rather than rendering a nameless talk.
-/
private def speakerHtml (talk : SeminarTalk) : Html :=
  if talk.speaker.shouldDisplay then miscItemInline talk.speaker
  else tbaHtml "Speaker to be announced"

/--
The speaker's affiliation in brackets, to follow their name, linked when the database has a URL
for it.

The opening bracket carries its own leading space. Verso's HTML printer may or may not put a
newline between this and the name depending on how the surrounding elements nest, and HTML
collapses a run of whitespace to one space either way -- but it will not invent a space that is not
there, so the space has to be in the text.
-/
private def affiliationHtml (talk : SeminarTalk) : Html :=
  match talk.affiliation.filter MiscItem.shouldDisplay with
  | none => .empty
  | some affiliation =>
    {{ <span class="talk-affiliation">" ("{{miscItemInline affiliation}}")"</span> }}

/--
The title, linked to the preprint or video when the entry carries one.

A scheduled talk often has no title yet, and saying so is more useful than leaving the line blank:
it tells a reader the entry is incomplete rather than that the talk is untitled.
-/
private def titleHtml (talk : SeminarTalk) : Html :=
  match talk.title.filter MiscItem.shouldDisplay with
  | some title => miscItemInline title
  | none => tbaHtml "Title to be announced"

/-- The row of links under a talk: its `misc` items, in the order they were written. -/
private def talkLinksHtml (talk : SeminarTalk) : Html :=
  let items := talk.visibleMisc
  if items.isEmpty then .empty
  else {{ <ul class="talk-links">{{ items.map miscItemHtml }}</ul> }}

/-- The date, with a machine-readable `datetime` beside the human-readable form. -/
private def dateHtml (date : Date) : Html :=
  {{ <time datetime={{date.toString}}>{{date.toListingString}}</time> }}

/--
A complete entry.

`collapseAbstract` is what distinguishes the two lists. On the upcoming list the abstract is the
reason to attend, so it is shown; in the archive it is folded into a `<details>`, so that a long
list of past talks can be scanned by date and speaker.
-/
private def talkHtml (collapseAbstract : Bool) (talk : SeminarTalk) : Html :=
  let abstractHtml :=
    match talk.abstract with
    | none => Html.empty
    | some abstract =>
      if collapseAbstract then
        {{
          <details class="talk-abstract">
            <summary>"Abstract"</summary>
            {{ paragraphsHtml abstract }}
          </details>
        }}
      else
        {{ <div class="talk-abstract">{{ paragraphsHtml abstract }}</div> }}
  {{
    <li class="talk">
      <div class="talk-when">{{ dateHtml talk.date }}</div>
      <div class="talk-what">
        <div class="talk-speaker">{{ speakerHtml talk }}{{ affiliationHtml talk }}</div>
        <div class="talk-title">{{ titleHtml talk }}</div>
        {{ abstractHtml }}
        {{ talkLinksHtml talk }}
      </div>
    </li>
  }}

/-- A whole list, or a note in its place when there is nothing to list. -/
private def talkListHtml (extraClass : String) (collapseAbstract : Bool) (emptyMessage : String)
    (talks : Array SeminarTalk) : Html :=
  if talks.isEmpty then
    {{ <p class="talk-list-empty">{{emptyMessage}}</p> }}
  else
    {{ <ul class=s!"talk-list {extraClass}">{{ talks.map (talkHtml collapseAbstract) }}</ul> }}

/-! ## The components and their directives -/

/--
Keep only the first `count` entries, when a count was given.

This exists so that the front page can show the last few talks without repeating the whole archive,
while `:::pastSeminars:::` with no argument still means "all of them".
-/
private def limitTo (count : Option Nat) (talks : Array SeminarTalk) : Array SeminarTalk :=
  match count with
  | some n => talks.take n
  | none => talks

/--
The talks still to come, earliest first, with abstracts shown.
-/
block_component upcomingSeminars (count : Option Nat) where
  toHtml _id _data _goI _goB _contents := do
    let today ← todayCached
    return talkListHtml "talk-list-upcoming" false
      "No talks are scheduled at the moment."
      (limitTo count (upcomingTalks today seminarTalks))

/--
The talks that have already happened, most recent first, with abstracts folded away.
-/
block_component pastSeminars (count : Option Nat) where
  toHtml _id _data _goI _goB _contents := do
    let today ← todayCached
    return talkListHtml "talk-list-past" true
      "The seminar has not met yet."
      (limitTo count (pastTalks today seminarTalks))

/-- The arguments both talk-list directives accept. -/
structure CountArgs where
  /-- Show at most this many talks. Omitted means all of them. -/
  count : Option Nat

instance : FromArgs CountArgs DocElabM where
  fromArgs := CountArgs.mk <$> .named `count .nat true

/--
Shared expansion for the two talk-list directives: check that no contents were given, then apply
the named component to the count.
-/
private def talkListDirective (component : Name) : DirectiveExpanderOf CountArgs
  | {count}, contents => do
    unless contents.isEmpty do
      logErrorAt (mkNullNode contents) s!"'{component.getString!}' takes no contents"
    let countStx ← match count with
      | none => ``(none)
      | some n => ``(some $(quote n))
    ``($(mkIdent component) $countStx #[])

/--
Lists the talks that are still to come, earliest first:

```
:::upcomingSeminars
:::
```

With `(count := n)`, only the next `n` are shown.
-/
@[directive upcomingSeminars]
def upcomingSeminarsDirective : DirectiveExpanderOf CountArgs :=
  talkListDirective ``upcomingSeminars

/--
Lists the talks that have already happened, most recent first:

```
:::pastSeminars
:::
```

With `(count := n)`, only the `n` most recent are shown -- which is how the front page shows a
handful without duplicating the archive.
-/
@[directive pastSeminars]
def pastSeminarsDirective : DirectiveExpanderOf CountArgs :=
  talkListDirective ``pastSeminars

end SeminarSite
