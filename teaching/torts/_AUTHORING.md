# Torts syllabus and course-site authoring

The canonical course files live outside this repository:

- `/Users/aplm/obsidian/teaching/MC Law/Torts/syllabus.md`
- `/Users/aplm/obsidian/teaching/MC Law/Torts/_schedule.md`
- `/Users/aplm/obsidian/teaching/MC Law/Torts/torts-materials.bib`

`syllabus.md` supplies the PDF and the shared website content.
`_schedule.md` supplies the meeting sequence to both outputs. There is no
`course.yml`, no second Quarto project, and no required preprocessing script.

## What to edit

1. Edit the YAML front matter in the Obsidian `syllabus.md` for short facts:
   course number, term, instructor, contact information, calendar bounds,
   regular meeting days and time, location, bibliography, and CSL alias.
2. Edit its Markdown body for the description, programmatic and course learning outcomes, grading,
   materials, policy summaries/details/rationales, and other shared prose.
3. Edit `_schedule.md` for modules, meeting topics, readings, assignments,
   no-class entries, special dates/times, and links to optional class pages.
4. Edit website files here only when changing presentation or page-specific
   prose. `index.md`, `schedule.md`, and `policies.md` load their substantive
   content from the external source. `syllabus-render.md` is a thin PDF
   adapter and should not contain course prose.

On the website Overview, keep shared sections in the same relative order as
they appear in the PDF: course description, programmatic learning outcomes,
course goals and learning outcomes, required materials, assessment and grading,
professional engagement, and syllabus revisions. Website-only material does
not interrupt that sequence.

Long fields stay in Markdown rather than YAML. The semantic fenced Divs in
`syllabus.md` tell the extension how to reuse them:

- `.course-share` exposes a named section to website pages and the PDF.
- `.course-materials-source` contains `.course-material` declarations.
- `.course-policies-source` contains `.course-policy` declarations.
- `.syllabus-summary` supplies the policy summary in either PDF mode and on the website.
- `.policy-detail` and `.policy-rationale` appear on the website and in a full-policy PDF.
- `.website-only` keeps a shared section out of the PDF.

## Local Bluebook CSL

The canonical syllabus refers to `.local/aplm-bluebook-syllabus.csl`. On this
computer that name is an ignored local symbolic link to:

`/Users/aplm/Library/Mobile Documents/com~apple~CloudDocs/Documents/pandoc-library/CSL/BluebookAPLM_syllabus.csl`

The CSL itself is not copied into or tracked by the repository. It is a local
syllabus derivative of the latest note-style CSL: its bibliography layout
leaves the terminal period to the extension so a hereinafter parenthetical can
precede that period. The original note-style CSL remains unchanged.

## Render and review

From `/Users/aplm/arturpericles.art`, the standard command generates the site
and PDF:

```sh
quarto render
```

For a faster editing loop:

```sh
quarto render teaching/torts/syllabus-render.md
quarto render teaching/torts/index.md
quarto render teaching/torts/schedule.md
quarto render teaching/torts/policies.md
```

`scripts/render-torts-course.sh` is an optional convenience only. Generated
files are published from `docs/`; the sidebar's **Syllabus** link
points directly to `/teaching/torts/syllabus.pdf`.

The PDF adapter controls policy length without changing the canonical policy
syntax. Set `syllabus-policy-display: summary` to convert each
`.syllabus-summary` into a compact bullet, or set it to `full` to print each
policy's italicized summary, details, and rationale. Torts currently uses
`full`. Full mode prints each policy's italicized summary followed directly by
its operational text and, when present, a **Why this policy exists** heading.
`syllabus-schedule-new-page: false` lets the schedule follow the full policies
without creating a mostly empty page.

## Schedule introduction

Text that should appear immediately below the **Schedule** heading belongs at
the end of `syllabus.md`, before the empty `.course-schedule` placeholder. Wrap
it in a named `.course-share` Div so the same prose is used by the PDF
and the website schedule page:

```markdown
# Schedule

::: {#schedule-note .course-share}
Subject to change as classes progress.
:::

::: {.course-schedule}
:::
```

The PDF prints this prose before the schedule table. The website's
`schedule.md` requests it with an empty
`{.course-section source="schedule-note"}` Div. Keep the introduction before
the `.course-schedule` placeholder; schedule entries themselves remain in
`_schedule.md`.

The website Schedule also places a `## Reading abbreviations` heading and an
empty `.course-materials` Div before the meeting list. That compact key is
generated from the canonical material declarations, so the displayed meanings
of **CB** and **FF** should never be written separately in `schedule.md`.

## Individual class page

Add `page: classes/<name>.html` to a schedule entry when that meeting should
link to an individual page. The page's `meeting-id` and the
`.class-preparation` placeholder must use the stable identifier from the
schedule heading. The extension then supplies the current class number, date,
readings, and assignments from `_schedule.md`:

```markdown
---
title: Introduction; What Is a Tort?
meeting-id: introduction-to-torts
---

::: {.course-section source="before-first-class"}
:::

::: {.class-preparation meeting-id="introduction-to-torts"}
:::

::: {.course-section source="before-first-class-context"}
:::
```

For the first meeting, this is the dedicated home for the website-only
`before-first-class` prose from `syllabus.md`, the generated Class 1
preparation, and the `before-first-class-context` follow-up. This arrangement
lets the generated preparation supply the current reading list inside the
welcome message. The welcome prose does not belong on the Overview or the
Schedule.

## Schedule entry

The regular calendar is defined in `syllabus.md`:

```yaml
course:
  start-date: 2026-08-17
  end-date: 2026-12-02
  meeting-days: [mon, wed, fri]
  meeting-time: "1:15–2:30 p.m."
  on-deck-groups: 5
```

Dates are inclusive and generated in chronological order. The Fall 2026 dates
are based on the [MC Law 2026–2027 Academic Calendar](https://law.mc.edu/application/files/7017/7886/5714/MC_Law_2026-2027_Academic_Calendar_04.06.26.pdf).
In `_schedule.md`,
write the topic as the level-four heading; do not write an ordinary date or a
separate topic paragraph:

```markdown
### Intentional Torts

#### Battery—Intent {#battery-intent}

- page: classes/battery-intent.html
- CB: 1–11
- FF: 25–30
- assignment: Prepare the intent hypothetical.
```

When `course.on-deck-groups` is set, counted meetings automatically rotate
through those panels. With a value of `5`, the website and PDF show Panel 1
through Panel 5 and then begin again at Panel 1. Holidays and no-class entries
are excluded automatically. Add the hidden `on-deck: no` field to a review,
practice session, examination, or other counted meeting that should neither
display a panel nor advance the rotation:

```markdown
#### Practice essay #1 {#practice1}

- on-deck: no
```

Ordinary meetings need no `on-deck` field.

Use `additional:` for an assigned reading that has no declared material
shorthand. The reading appears without an `Additional` prefix. Use `optional:`
only for genuinely optional material. The former `supplemental:` field is no
longer supported; change any such entry to `additional:`:

```markdown
- additional: Required article distributed through the course site.
- optional: First enrichment reading.
- optional: Second enrichment reading.
```

A single optional reading uses an inline italic *Optional:* prefix. Repeating
`optional:` groups the readings beneath one italic *Optional:* label in both
outputs. The *Assignment:* run-in label is bold italic rather than underlined,
because underlining would look like a link on the website. Repeating
`assignment:` produces a nested list under the plural bold-italic label
*Assignments:*:

```markdown
- assignment: Prepare the intent hypothetical.
- assignment: Submit the short response before class.
```

Entries stay in source order within each *Optional:* or *Assignments:* group.
Repeated `additional:` entries remain separate, unlabeled readings. A single
`assignment:` remains inline after *Assignment:* rather than becoming a nested
list.

Use ordinary Markdown emphasis for case names in reading parentheticals and
for Latin phrases. This explicit markup is preserved in both outputs:

```markdown
- CB: 89–91 (*Ploof* and Notes 1–2)
#### Negligence *per se*; judge and jury {#negligence-per-se}
```

Use en dashes for numeric and time ranges (`89–91`, `1:15–2:30 p.m.`),
em dashes for title breaks (`Battery—intent`), and hyphens for genuine
compound words and machine-readable ISO dates.

Level-three headings are numbered automatically in both outputs. Write only
the unit title. Add `{.unnumbered}` when a section should display without the
entire `Unit N —` prefix and should not advance the unit counter:

```markdown
### Introduction {.unnumbered}
### Intentional Torts
```

The heading identifier is stable even if automatic class numbers change.

A fixed closure (`no-class`, `holiday`, `canceled`, or `cancelled`) must include
its normal calendar date and does not receive a class number. The explicit date
prevents a reordered session from silently moving the closure:

```markdown
#### Labor Day {#labor-day}

- type: no-class
- date: 2026-09-07
```

The closure date must match a generated regular meeting date. Rendering fails
if the date is missing, off-pattern, duplicated, skipped, or out of order.

For an off-pattern midterm, final, or makeup, add an ISO date and the special
time to that meeting. Such a date may fall outside the normal meeting weekdays
or the `start-date`/`end-date` bounds:

```markdown
#### Final examination {#final-examination}

- date: 2026-12-10
- time: 1:00–4:00 p.m.
- counts-as-class: no
```

An override that coincides with a generated meeting date consumes that slot;
an off-pattern override adds a meeting without consuming one. To record a
cancellation and makeup, keep the dated no-class entry for the canceled regular
date and add a later dated makeup entry. Keep all entries chronological.
Rendering fails on duplicate dates, skipped regular dates, out-of-order
entries, or a schedule whose ordinary entries do not exactly cover the
generated calendar.
