/-!
# Site-wide settings

The handful of strings that appear on *every* page: the name in the header, the browser tab title,
the footer, and the seminar's regular time and place. `Main.lean` reads them from here so that
renaming the seminar -- or moving it to a new room -- is one edit rather than one edit per page.

The time and place reach the prose through the `{timeAndPlace}[]` role, defined in
`SeminarSite/Render.lean`.

Anything that appears on a single page belongs in that page's markup under `SeminarSite/Pages/`,
not here.
-/

namespace SeminarSite

/-- The strings that the page template needs on every page. -/
structure SeminarConfig where
  /-- The seminar's full name, shown in the site header. -/
  name : String
  /-- A short form for the browser tab, appended after each page's own title. -/
  shortName : String
  /-- One line under the name in the header. Leave empty to omit it. -/
  tagline : String
  /--
  When the seminar meets, phrased so that it reads after "the seminar meets" --
  e.g. "Fridays at 13:15-14:00", or "every second Tuesday at 10:15".
  -/
  meetingTime : String
  /-- The room, e.g. "room U4062". -/
  meetingRoom : String
  /--
  The building the room is in, e.g. "main building of University of Helsinki".
  `none` drops the "of the ..." clause from the phrase.
  -/
  meetingBuilding : Option String := none
  /--
  The street address of that building, e.g. "Fabianinkatu 33".
  `none` drops the parenthesis from the phrase.
  -/
  meetingAddress : Option String := none
  /-- Contact address, shown in the footer. `none` omits it. -/
  contactEmail : Option String := none
  /-- Where this site's source lives, shown in the footer. `none` omits the link. -/
  repoUrl : Option String := none
  /-- The footer's copyright line. -/
  copyright : String
  deriving Inhabited

/-- This site's settings. -/
def seminarConfig : SeminarConfig where
  name := "Seminar on Formalized Mathematics"
  shortName := "Formalization Seminar"
  tagline := "A joint seminar of University of Helsinki and Aalto University"
  meetingTime := "Fridays at 13:15–14:00"
  meetingRoom := "room U4062"
  meetingBuilding := some "main building of University of Helsinki"
  meetingAddress := some "Fabianinkatu 33"
  -- `some "someone@example.org"` puts a mailto link in the footer.
  contactEmail := none
  repoUrl := none
  copyright := "© 2026 the seminar organisers"

end SeminarSite
