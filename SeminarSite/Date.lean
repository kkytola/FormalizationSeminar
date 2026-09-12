import Std.Time

/-!
# Dates

A date type. `year` is mandatory; `month` and `day` are optional.
-/

namespace SeminarSite

/-- A date with mandatory year and optional month/day -/
structure Date where
  /-- Year (e.g. 2026) -/
  year : Nat
  /-- Month (1-12), optional -/
  month : Option Nat := none
  /-- Day (1-31), optional -/
  day : Option Nat := none
  deriving Repr, BEq, DecidableEq, Inhabited

namespace Date

/-- Create a date with just a year -/
def fromYear (year : Nat) : Date :=
  { year := year }

/-- Create a date with year and month -/
def fromYearMonth (year month : Nat) : Date :=
  { year := year, month := some month }

/-- Create a complete date with year, month, and day -/
def fromYearMonthDay (year month day : Nat) : Date :=
  { year := year, month := some month, day := some day }

/-- Parse a date from ISO 8601 format (YYYY, YYYY-MM, or YYYY-MM-DD) -/
def parse? (s : String) : Option Date :=
  let parts := s.splitOn "-"
  match parts with
  | [y] =>
      y.toNat?.map fromYear
  | [y, m] =>
      match y.toNat?, m.toNat? with
      | some year, some month => some (fromYearMonth year month)
      | _, _ => none
  | [y, m, d] =>
      match y.toNat?, m.toNat?, d.toNat? with
      | some year, some month, some day => some (fromYearMonthDay year month day)
      | _, _, _ => none
  | _ => none

/-- Format a date as ISO 8601 string (YYYY, YYYY-MM, or YYYY-MM-DD) -/
def toString (date : Date) : String :=
  let yearStr := Nat.repr date.year
  match date.month, date.day with
  | none, _ => yearStr
  | some m, none =>
      let monthStr := if m < 10 then s!"0{m}" else Nat.repr m
      s!"{yearStr}-{monthStr}"
  | some m, some d =>
      let monthStr := if m < 10 then s!"0{m}" else Nat.repr m
      let dayStr := if d < 10 then s!"0{d}" else Nat.repr d
      s!"{yearStr}-{monthStr}-{dayStr}"

instance : ToString Date where
  toString := toString

/-- The month names used by `toHumanString`. Index 0 is unused, so that `monthNames[m]!` is the
name of month `m`. -/
def monthNames : Array String :=
  #["", "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"]

/-- Format a date in a human-readable format -/
def toHumanString (date : Date) : String :=
  match date.month, date.day with
  | none, _ => Nat.repr date.year
  | some m, none =>
      if h : m < monthNames.size then
        s!"{monthNames[m]} {date.year}"
      else
        toString date
  | some m, some d =>
      if h : m < monthNames.size then
        s!"{monthNames[m]} {d}, {date.year}"
      else
        toString date

/-- Compare two dates (for sorting) -/
def compare (a b : Date) : Ordering :=
  match Ord.compare a.year b.year with
  | .lt => .lt
  | .gt => .gt
  | .eq =>
      match a.month, b.month with
      | none, none => .eq
      | none, some _ => .lt
      | some _, none => .gt
      | some ma, some mb =>
          match Ord.compare ma mb with
          | .lt => .lt
          | .gt => .gt
          | .eq =>
              match a.day, b.day with
              | none, none => .eq
              | none, some _ => .lt
              | some _, none => .gt
              | some da, some db => Ord.compare da db

instance : Ord Date where
  compare := Date.compare

/-- Sort items by date in descending order (newest first).
    Items with dates come before items without dates. -/
def sortByDateDesc {α : Type} (getDate : α → Option Date) (items : Array α) : Array α :=
  items.qsort fun a b =>
    match getDate a, getDate b with
    | some da, some db => Date.compare da db == .gt
    | some _, none => true
    | none, some _ => false
    | none, none => false

/-- Sort items by date in ascending order (oldest first).
    Items with dates come before items without dates. -/
def sortByDateAsc {α : Type} (getDate : α → Option Date) (items : Array α) : Array α :=
  items.qsort fun a b =>
    match getDate a, getDate b with
    | some da, some db => Date.compare da db == .lt
    | some _, none => true
    | none, some _ => false
    | none, none => false

/-- Sort items by date with year fallback, in descending order (newest first).
    Primary sort: by date if available
    Secondary sort: by year if date is not available
    Items with date/year come before items without either. -/
def sortByDateOrYear {α : Type}
    (getDate : α → Option Date)
    (getYear : α → Option Int)
    (items : Array α) : Array α :=
  items.qsort fun a b =>
    match getDate a, getDate b with
    | some da, some db => Date.compare da db == .gt
    | some _, none => true
    | none, some _ => false
    | none, none =>
        -- Fall back to year comparison
        match getYear a, getYear b with
        | some ya, some yb => ya > yb
        | some _, none => true
        | none, some _ => false
        | none, none => false

/--
The last day of the period a `Date` denotes.

A `Date` with an omitted month or day denotes a *period*, not an instant: `⟨2026, some 10, none⟩`
means "some time in October 2026". Asking whether such a talk is still upcoming is therefore
asking whether the period it names has finished, which is what this answers. `2026-10` becomes
`2026-10-31`, and a bare `2026` becomes `2026-12-31`, so an imprecisely dated talk stays in the
upcoming list for as long as it could still happen rather than dropping into the archive on the
first of the month.

The day is the real last day of the month, leap years included, so that this stays a genuine date
and not just a sort key.
-/
def endOfPeriod (date : Date) : Date :=
  let month := date.month.getD 12
  let day := date.day.getD (daysInMonth date.year month)
  { year := date.year, month := some month, day := some day }
where
  isLeapYear (y : Nat) : Bool := y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)
  daysInMonth (y m : Nat) : Nat :=
    match m with
    | 1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    | 4 | 6 | 9 | 11 => 30
    | 2 => if isLeapYear y then 29 else 28
    -- An out-of-range month is a typo in the talk database. 31 keeps the entry sorted roughly
    -- where it belongs rather than silently moving it; `Date.isValid` is what reports the typo.
    | _ => 31

/--
Whether a date is one that could actually occur: a month in `1-12` and, if given, a day that
exists in that month of that year.

Nothing rejects an invalid date -- it will still render and sort -- but `Main.lean` reports one as
a warning while generating, which is how a mistyped `⟨2026, some 13, some 40⟩` gets noticed.
-/
def isValid (date : Date) : Bool :=
  match date.month with
  | none => date.day.isNone
  | some m =>
    1 ≤ m && m ≤ 12 &&
      match date.day with
      | none => true
      | some d => 1 ≤ d && d ≤ endOfPeriod.daysInMonth date.year m

/--
Today's date, in UTC.

Deliberately UTC rather than the machine's local zone: this is read while the site is being
generated, and it should not matter whether that happens on a GitHub runner or on a laptop in
Helsinki. A seminar's talks are a day apart, so a few hours of offset never changes which list a
talk lands in.

Setting `SEMINAR_TODAY` to an ISO 8601 date overrides the clock, which is how you preview what the
site will look like on some other day:

```
SEMINAR_TODAY=2027-01-15 lake exe generate-site
```
-/
def today : IO Date := do
  if let some s ← IO.getEnv "SEMINAR_TODAY" then
    if let some d := parse? s.trimAscii.copy then
      return d
    else
      throw <| IO.userError
        s!"SEMINAR_TODAY is set to '{s}', which is not an ISO 8601 date (YYYY, YYYY-MM or YYYY-MM-DD)"
  -- `Timestamp.now` plus a fixed zone, rather than `PlainDate.now`, because the latter reads the
  -- system time zone database and there is no reason to depend on that being present.
  let now ← Std.Time.Timestamp.now
  -- `DateTime.date` is a `Thunk`, so `.get` forces it; the second `.date` drops the time of day.
  let date := (Std.Time.DateTime.ofTimestampWithZone now .UTC).date.get.date
  return {
    year := date.year.toNat,
    month := some date.month.val.toNat,
    day := some date.day.val.toNat
  }

/--
The day of the week, as a three-letter abbreviation, for a date whose day is known.

Which weekday a talk falls on is the thing a reader of a weekly seminar page scans for, so it is
worth showing even though the data does not store it.
-/
def weekdayAbbrev? (date : Date) : Option String := do
  let m ← date.month
  let d ← date.day
  let plain ← Std.Time.PlainDate.ofYearMonthDay? (date.year : Int) (← toBounded 1 12 m) (← toBounded 1 31 d)
  let names := #["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
  names[plain.weekday.toOrdinal.val.toNat - 1]?
where
  /-- `Std.Time` indexes months and days with proof-carrying bounded integers. -/
  toBounded (lo hi n : Nat) : Option (Std.Time.Internal.Bounded.LE lo hi) :=
    if h : lo ≤ n ∧ n ≤ hi then
      some ⟨(n : Int), by omega⟩
    else
      none

/--
A date as it is shown in the talk lists: `"Thu 1 October 2026"`, falling back to
`Date.toHumanString` when the weekday cannot be determined because the day is not recorded.

Day before month, unlike `toHumanString`: these lists are read as a column of dates, and the day
is what distinguishes neighbouring rows.
-/
def toListingString (date : Date) : String :=
  match date.month, date.day with
  | some m, some d =>
    if h : m < monthNames.size then
      let dayName := match weekdayAbbrev? date with
        | some w => w ++ " "
        | none => ""
      s!"{dayName}{d} {monthNames[m]} {date.year}"
    else
      toString date
  | _, _ => toHumanString date

end Date

end SeminarSite
