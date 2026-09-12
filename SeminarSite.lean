import SeminarSite.Config
import SeminarSite.Date
import SeminarSite.Talk
import SeminarSite.Data.SeminarTalkData
import SeminarSite.Render
import SeminarSite.Pages.Front
import SeminarSite.Pages.PastTalks
import SeminarSite.Pages.PracticalInfo
import SeminarSite.Pages.Organizers

/-!
# The seminar site

The library root. Everything the site consists of is imported above, which is what makes
`lake build` type-check all of it: only this module is named as a Lake target, so a page that
nothing imports is a page that is never checked.

If you add a page under `SeminarSite/Pages/`, add it here *and* to the `site` declaration in
`Main.lean`. The import makes it compile; the `site` declaration is what puts it on the web.
-/
