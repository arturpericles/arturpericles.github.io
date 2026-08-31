# APLM course extension

This extension gives one Quarto website two related outputs:

- reusable HTML course components; and
- a `course-pdf` format that can produce a concise or comprehensive MC Law syllabus.

The canonical course document is ordinary Markdown with YAML front matter. It
may live outside the website repository. In the Torts implementation,
`/Users/aplm/obsidian/teaching/MC Law/Torts/syllabus.md` contains the course
facts, description, learning outcomes, grading, material declarations, and
policies. `_schedule.md` lives beside it because both outputs parse the same
meeting entries.

No `course.yml`, separate syllabus project, or preprocessing script is
required.

## Project wiring

The course directory's `_metadata.yml` points HTML pages at the canonical
document and enables the website filter only for HTML:

```yaml
course-site: true
course-source: syllabus.md
course-source-dir: "../obsidian/teaching/MC Law/Torts"
resource-path:
  - .
  - "../obsidian/teaching/MC Law/Torts"
format:
  html:
    filters:
      - aplm/course
```

The repository keeps a thin adapter that selects the extension's PDF format:

```yaml
---
title: Syllabus
format: course-pdf
output-file: syllabus.pdf
syllabus-policy-display: full
syllabus-schedule-new-page: false
syllabus-page-break-before:
  - grading
course-source: syllabus.md
course-source-dir: "../obsidian/teaching/MC Law/Torts"
---
```

The canonical document supplies `course`, `course-schedule`, `bibliography`,
and `csl` metadata. Course-material citations are rendered from the selected
CSL's bibliography layout and inserted inline. A note-style Bluebook CSL can
therefore remain unchanged without producing syllabus footnotes.

The `course` mapping also defines the regular calendar once:

```yaml
course:
  start-date: 2026-08-17
  end-date: 2026-12-04
  meeting-days: [mon, wed, fri]
  meeting-time: "1:15–2:30 p.m."
  on-deck-groups: 5
```

The website spells out the meeting days in its course facts. The PDF derives a
compact meeting value from the same fields (for example, `M, W, F,
1:15–2:30 p.m.`), so no second schedule string is needed.

The bounds are inclusive. The extension generates every matching date and
derives the human-readable meeting summary used in the site and PDF.

## Shared Markdown sections

Long content stays outside YAML. A `.course-share` Div gives a section a stable
name that HTML pages can request:

```markdown
::: {.course-share #learning-outcomes}
# Course Goals and Learning Outcomes

- Explain key tort principles.
- Apply rules to new fact patterns.
:::
```

An HTML page places the section with:

```markdown
::: {.course-section source="learning-outcomes"}
:::
```

The PDF unwraps the same section and prints it in source order. Add
`.website-only` to a shared section that should be available to the website but
omitted from the PDF.

## Course facts

An HTML page can render the canonical course metadata as a compact grid:

```markdown
::: {.course-facts}
:::
```

The grid reads practical logistics from `course:` YAML: meeting information,
location, office, teaching-assistant names, and office hours. Fields that are
not set are omitted. The `office` field is optional; when the office location
is already included in `office-hours`, it may be left unset without leaving
punctuation in the PDF.

List teaching assistants in the canonical course metadata:

```yaml
course:
  teaching-assistants:
    - First TA Name
    - Second TA Name
```

A single scalar name is also accepted. The Overview uses a singular label for
one name and a plural label and compact inline list for multiple names. The PDF
syllabus repeats the names in its first-page course-information block.

## Materials

Materials are declared semantically in Markdown, not YAML:

```markdown
:::: {.course-materials-source}
::: {.course-material shorthand="CB" citekey="farnsworth-grady2019"}
The third edition is required.
:::
::::
```

The website's empty `.course-materials` Div and the PDF both render these
declarations. Schedule labels such as `CB:` must match a declared shorthand.

## Policies

Each policy keeps its concise rule, operational detail, and rationale together:

```markdown
:::: {.course-policies-source}
::: {.course-policy #preparation}
## Preparation and participation

::: {.syllabus-summary}
Complete assigned readings before class.
:::

::: {.policy-detail}
The fuller operational explanation.
:::

::: {.policy-rationale}
Why the policy exists.
:::
:::
::::
```

The Course Policies webpage renders each summary with its detail and rationale.
For the PDF, `syllabus-policy-display: summary` converts the summaries into a
compact bulleted list. `syllabus-policy-display: full` instead prints every
policy heading, an unlabelled italic summary, its operational text without an
extra heading, and its rationale under **Why this policy exists**. The policy
renderer reserves enough page room to keep each concise policy heading,
summary, and operational statement together; its rationale may continue
separately.
The canonical policy syntax is identical in both modes. When the full mode
would leave a mostly empty page before the schedule, set
`syllabus-schedule-new-page: false` in the PDF adapter.

To start selected shared sections on a fresh PDF page without changing the
website, set `syllabus-page-break-before` to a named `.course-share` id or YAML
list of ids in the PDF adapter. A configured id that is not found fails the
render rather than silently omitting the requested break.

## Schedule

`_schedule.md` uses level-three unit headings, level-four topic headings with
stable identifiers, and labeled list items. Each level-four entry receives the
next regular meeting date:

```markdown
### Intentional Torts

#### Battery—Intent {#battery-intent}

- page: classes/battery-intent.html
- CB: 1–11
- FF: 25–30
- assignment: Prepare the intent hypothetical.
```

The extension prefixes ordinary level-three headings with an incrementing
unit number. Write only the unit title in the source. Mark a heading
`{.unnumbered}` to display it without the entire `Unit N —` prefix; an
unnumbered heading does not advance the counter:

```markdown
### Introduction {.unnumbered}
### Intentional Torts
```

Reserved labels are `activity`, `assignment`, `counts-as-class`, `note`,
`additional`, `date`, `on-deck`, `optional`, `page`, `rescheduled-to`, `room`,
`time`, and `type`. The filter numbers counting meetings automatically. `cancelled`,
`canceled`, `holiday`, `no-class`, and `schedule-note` do not count unless the
entry sets `counts-as-class: yes`.

`course.on-deck-groups` generates a repeating On Deck panel rotation for counted
meetings in both outputs. Set `on-deck: no` on a review, practice session,
examination, or other counted meeting to omit it without advancing the
rotation. No-class entries are omitted automatically; ordinary meetings need
no field.

Use `additional:` for a reading that is assigned without a book shorthand. It
renders as a reading with no category prefix. Use `optional:` only for material
that students may choose whether to read. The former `supplemental:` field is
no longer supported; change any such entry to `additional:`. One optional
reading receives an inline italic *Optional:* prefix; repeated optional fields
are grouped beneath one italic *Optional:* label:

```markdown
- additional: Required article distributed through the course site.
- optional: First enrichment reading.
- optional: Second enrichment reading.
```

The run-in *Assignment:* label is bold italic in both outputs. Repeating
`assignment:` groups the entries beneath a bold-italic *Assignments:* label
with a nested list:

```markdown
- assignment: Prepare the intent hypothetical.
- assignment: Submit the short response before class.
```

Use ordinary Markdown emphasis for case names in reading parentheticals and
for Latin phrases. The extension preserves the emphasis in both outputs:

```markdown
- CB: 89–91 (*Ploof* and Notes 1–2)
#### Negligence *per se*; judge and jury {#negligence-per-se}
```

Use en dashes for numeric and time ranges (`89–91`, `1:15–2:30 p.m.`),
em dashes for title breaks (`Battery—intent`), and hyphens for genuine
compound words and machine-readable ISO dates.

Entries stay in source order within each *Optional:* or *Assignments:* group.
Repeated `additional:` entries remain separate, unlabeled readings. A single
`assignment:` remains inline after *Assignment:* rather than becoming a nested
list. Underlining is avoided because it suggests a hyperlink on the website.

A fixed closure (`no-class`, `holiday`, `canceled`, or `cancelled`) must declare
its regular meeting date explicitly. The date anchors the closure so rearranging
meeting topics cannot silently move it:

```markdown
#### Labor Day {#labor-day}

- type: no-class
- date: 2026-09-07
```

The date must be one of the generated regular meeting dates. Rendering fails
when a fixed closure omits its date, uses an off-pattern date, or appears out of
chronological order. This turns a conflicting schedule edit into an error rather
than reassigning the closure.

Use `date: YYYY-MM-DD` for a special meeting. An off-pattern midterm, final, or
makeup class may be outside the ordinary meeting weekdays or the regular
calendar bounds. `time:` overrides the displayed meeting time for that entry;
`counts-as-class: no` suppresses its class number when appropriate:

```markdown
#### Final examination {#final-examination}

- date: 2026-12-10
- time: 1:00–4:00 p.m.
- room: Exam room announced by the Registrar
- counts-as-class: no
```

An override matching a generated date consumes that date. An off-pattern
override is an additional meeting and does not consume a regular date. Thus a
dated canceled class and its later dated makeup should be separate entries.
Entries must remain chronological, identifiers and dates must be unique, and
every regular date must be represented by either a meeting or a fixed closure.

## Rendering

From the website project root, a normal project render generates the HTML site
and the concise PDF:

```sh
quarto render
```

During editing, target only the output being checked:

```sh
quarto render teaching/torts/syllabus-render.md
quarto render teaching/torts/index.md
quarto render teaching/torts/schedule.md
```

The project may keep a shell script as a convenience for targeted renders, but
the extension and Quarto project do not depend on it.

The HTML components inherit the parent site's fonts and use MC Blue
(`#0C2340`), MC Gold (`#C99700`), and Celestial Blue (`#69B3E7`). The website
does not display an institutional logo; the PDF format carries the MC Law logo.
