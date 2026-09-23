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

  { speaker := { desc := "—" }
    date := Date.fromYearMonthDay 2026 10 23
    title := "— NO SEMINAR —" },

  { speaker := { desc := "Kristian Latvanen" }
    affiliation := "Aalto University"
    date := Date.fromYearMonthDay 2026 10 16
    title := "Formalizing percolation"
    abstract := r#"I will describe our current project on formalizing percolation theory, more specifically, sharpness of percolation phase transition. Due to advances in AI, the emphasis of the project has shifted somewhat, most recently due to a full LLM-generated formalization of the original goal by Anthropic. Especially, I will describe what has been learned in writing a Mathlib-quality version of the result and the usefulness of LLMs in it."#
    },

  { speaker := "Thanh-Long Tran"
    affiliation := "University of Helsinki"
    date := Date.fromYearMonthDay 2026 10 9
    title := none },

  { speaker := "Niklas Halonen"
    affiliation := "University of Helsinki"
    date := Date.fromYearMonthDay 2026 10 2
    title := "Automated Grading in Lean Using Comparator"
    abstract := r#"In my talk, I give an introduction to Comparator and briefly explain the principles and challenges behind it. I will also demonstrate my tool for automated grading of Lean exercises called "comparator-autograder"."#
  },

  { speaker := { desc := "Janne Junnila", link := some "https://junnila.me/"}
    affiliation := "University of Jyväskylä"
    date := Date.fromYearMonthDay 2026 9 25
    title := "In search for practical autoformalization workflows for working mathematicians",
    abstract := "I will present a personal account of my own autoformalization experiments in complex analysis and related areas. This will include a demo of Handwave, which is a tool intended to help in planning, building, organizing and presenting autoformalized Lean projects."
    },

  { speaker := "Talal Alrawajfeh"
    affiliation := "University of Helsinki"
    date := Date.fromYearMonthDay 2026 9 11
    title := none },
]

end SeminarSite
