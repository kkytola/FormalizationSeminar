import SeminarSite.Date

/-!
# Seminar talks

The data structure for one seminar talk, and the queries the pages run against the database in
`SeminarSite.Data.SeminarTalkData`.

Only `speaker` and `date` are mandatory. Everything else is optional, because a seminar schedule is
filled in piecemeal: a speaker is invited months before a title exists, and a title long before an
abstract.

There is one database, `seminarTalks`, and the upcoming and past lists are both views of it
(`upcomingTalks` and `pastTalks`). Nothing has to be moved from one list to the other when a talk
happens; a talk changes list because the date passes, not because anyone edits the file.
-/

namespace SeminarSite

/-- A miscellaneous item that can be plain text, linked text, or omitted -/
structure MiscItem where
  /-- Description text (required) -/
  desc : String
  /-- Optional link URL -/
  link : Option String := none
  /-- Whether to hide this item (none and some false both mean show) -/
  dontshow : Option Bool := none
  deriving Repr, BEq, Inhabited

/-- Check if a MiscItem should be displayed -/
def MiscItem.shouldDisplay (item : MiscItem) : Bool :=
  match item.dontshow with
  | some true => false
  | _ => true

/--
Text with no link is the common case, so a bare string counts as a `MiscItem`:
`speaker := "Emmy Noether"` instead of `speaker := { desc := "Emmy Noether" }`.

This is what keeps the talk database readable now that the speaker, the affiliation and the title
are all `MiscItem`s rather than plain strings.
-/
instance : Coe String MiscItem where
  coe desc := { desc := desc }

/--
One talk in the seminar.

The speaker, the affiliation and the title are all `MiscItem`s, because each is a piece of text
that may or may not carry a link, which is exactly what a `MiscItem` is. A bare string coerces to
one, so the common case stays short.

`misc` holds the extras that accumulate around a talk and that do not deserve a field of their own:
slides, a recording, a related paper, a note that the time is unusual. Each is shown as a small
labelled link (or as plain text when it has no URL), and an item can be kept in the file but hidden
from the site with `dontshow := some true` -- useful for a recording link that is not public yet.
-/
structure SeminarTalk where
  /--
  Who is speaking, with `link` their home page. The one field that is always known.

  `dontshow := some true` renders "Speaker to be announced" -- for a date that is reserved before
  the invitation can be made public.
  -/
  speaker : MiscItem
  /-- When. Mandatory, and the only thing that decides whether the talk is upcoming or past. -/
  date : Date
  /--
  Where the speaker is from, shown in brackets after their name, with `link` the institution's or
  department's page.
  -/
  affiliation : Option MiscItem := none
  /--
  The title of the talk once it is known, with `link` a preprint, an arXiv entry or a video.

  Until then, or with `dontshow := some true`, the entry says "Title to be announced".
  -/
  title : Option MiscItem := none
  /-- The abstract, as plain text. Blank lines separate paragraphs. -/
  abstract : Option String := none
  /-- Slides, recordings, related papers, notes about an unusual time or room. -/
  misc : List MiscItem := []
  deriving Repr, BEq, Inhabited

namespace SeminarTalk

/-- The `misc` items that should actually be shown, in the order they were written. -/
def visibleMisc (talk : SeminarTalk) : List MiscItem :=
  talk.misc.filter MiscItem.shouldDisplay

/--
Whether the talk is still to come, as of `today`.

A talk counts as upcoming for the whole of its last possible day, so today's talk appears under
"upcoming" rather than vanishing into the archive on the morning of the seminar. For a talk whose
date is imprecise this is the last day of the period it names -- see `Date.endOfPeriod`.
-/
def isUpcoming (today : Date) (talk : SeminarTalk) : Bool :=
  Date.compare talk.date.endOfPeriod today != .lt

/--
A total order on talks for a given date order, so that the generated HTML is reproducible.

Sorting by date alone would leave talks that share a date in whatever order `Array.qsort` happens
to produce, which can differ between runs and makes the published site churn. Speaker and title
break the tie.
-/
private def orderBy (dateOrder : Date → Date → Ordering) (a b : SeminarTalk) : Ordering :=
  (dateOrder a.date b.date)
    |>.then (Ord.compare a.speaker.desc b.speaker.desc)
    |>.then (Ord.compare (titleText a) (titleText b))
where
  titleText (talk : SeminarTalk) : String := (talk.title.map (·.desc)).getD ""

/-- Earliest first: the order an upcoming-talks list is read in. -/
def sortedAscending (talks : Array SeminarTalk) : Array SeminarTalk :=
  talks.qsort fun a b => orderBy Date.compare a b == .lt

/-- Most recent first: the order an archive is read in. -/
def sortedDescending (talks : Array SeminarTalk) : Array SeminarTalk :=
  talks.qsort fun a b => orderBy (fun x y => (Date.compare x y).swap) a b == .lt

end SeminarTalk

/-- The talks still to come, earliest first. -/
def upcomingTalks (today : Date) (talks : Array SeminarTalk) : Array SeminarTalk :=
  SeminarTalk.sortedAscending <| talks.filter (SeminarTalk.isUpcoming today)

/-- The talks that have already happened, most recent first. -/
def pastTalks (today : Date) (talks : Array SeminarTalk) : Array SeminarTalk :=
  SeminarTalk.sortedDescending <| talks.filter (fun t => !t.isUpcoming today)

/--
Talks whose recorded date could not occur, as a list of human-readable complaints.

`Main.lean` prints these while generating. A talk on the 31st of February is a typo, and a typo in
a date is exactly the kind of mistake that would otherwise be discovered by a reader wondering why
a talk never moved out of the upcoming list.
-/
def dateProblems (talks : Array SeminarTalk) : Array String :=
  talks.filterMap fun talk =>
    if talk.date.isValid then none
    else some s!"{talk.speaker.desc}: '{talk.date}' is not a possible date"

end SeminarSite
