import SeminarSite.Talk

/-!
# The talk database

One array, `seminarTalks`, containing every talk the seminar has ever had and every talk it has scheduled.
Order does not matter here -- the pages classify to upcoming and past talks and sort them by the date.
Keeping entries in roughly reverse chronological order is the simplest for editing.

## Adding a talk

Only `speaker` and `date` are needed:

```
{ speaker := "David Hilbert"
  date := Date.fromYearMonthDay 1900 8 8 },
```

Fill in `title`, `affiliation` and `abstract` when you get them. `Date.fromYearMonth 2026 11` records a talk that
is known to be in November but has no fixed day yet; it stays under "Upcoming" until the end of
that month.
-/

namespace SeminarSite

open SeminarSite (Date)

/--
Every talk in the seminar, past and future, in one array.
-/
def seminarTalks : Array SeminarTalk := #[

  { speaker := { desc := "Kristian Latvanen" }
    affiliation := "Aalto University",
    date := Date.fromYearMonth 2026 9
    title := "Formalizing the sharpness of percolation phase transition" },

  { speaker := "Talal Alrawajfeh",
    affiliation := "University of Helsinki",
    date := Date.fromYearMonthDay 2026 9 11
    title := none },
]

end SeminarSite
