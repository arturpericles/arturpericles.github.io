# Talks design record — November 11, 2026

The user selected the venue-led record on November 11, 2026 and authorized its
publication together with the Foundations of AI Law course subtitle update.
The aligned register and Year bundles remain preserved as alternatives.

## Authoritative content and rendering

- `talks/appearances.yml` is the sole current source of appearances. It replaces
  the two former lists. Historical titles and review information are preserved.
- Publication pages supply canonical and short paper titles through the Quarto
  custom listing. The `paper` key identifies a publication directory. Add its
  `index.md` to the listing contents when introducing a new publication reference.
- `talks/talks.ejs`, `talks/talks.css`, and `talks/titles.html` implement the register,
  responsive layout, and Bootstrap hover/focus titles with native title fallback.
- `legacy/` preserves the former source files, including the commented Ottawa
  appearance. These are historical snapshots, not active data sources.

## Alternative designs retained for future use

`unified-venues-proposals.html` is the original three-design conversation fragment:
Venue-led record, Aligned register, and Year bundles. It retains the exact design
state shown before the final record corrections. Its content is historical: DLI
was still a talk and dates lacked periods. Do not use it as a content authority.
Open it through the conversation visualization renderer to use its carousel.

The selected venue-led record uses `template-params.layout: venue-led` in the
main page. `aligned-register.yml` switches back to the aligned register without
changing the data or theme. To rebuild both local previews from the site root:

```sh
quarto render talks/index.md --profile local-preview --no-clean
quarto render talks/index.md --profile local-preview --no-clean --output aligned-register.html --metadata-file _design/talks/aligned-register.yml
mv .local/site/aligned-register.html .local/site/talks/aligned-register.html
```

The final move keeps the source-relative asset paths valid. Preview paths:

- `.local/site/talks/index.html`: selected venue-led record.
- `.local/site/talks/aligned-register.html`: aligned register alternative.
- `.local/site/teaching/foundations-of-ai-law/index.html`: corrected course subtitle.

This underscore-prefixed directory is excluded from ordinary Quarto project
rendering. Alternative previews stay outside `docs`.

## Accepted corrections

- DLI is a Platform Federalism paper presentation, March 13, 2025.
- The UN venue reads “United Nations, Department of Political and Peacebuilding
  Affairs”; the unit is retained separately in the data. The contribution is
  “Briefing Series on Social Media”.
- Locations and remote participation are secondary details.
- Months use Jan., Feb., Mar., Apr., May, June, July, Aug., Sept., Oct., Nov., Dec.
- No visible column labels, repeated table captions, or presentation counts.
- Foundations of AI Law uses the shared course styling and subtitle
  “MC Law · Professor Monteiro · Spring 2027”. Its course body remains an include
  from the authoritative Obsidian course file.

## Verification and release boundary

Both layouts were visually checked at the default browser width and 390px.
Neither overflowed horizontally. The full paper title appeared on keyboard
focus; the same Bootstrap component is configured for hover. All appearance
records remain present in both layouts. Hidden table headers and captions retain
screen-reader context. Local screenshots are in `.local/talks-release/`.

The generated `docs` version contains the selected venue-led record. The user
authorized the push. The unrelated pre-existing change to `scripts/post-render.sh`
and `_quarto-local-preview.yml` are outside this release. The local preview profile
is needed for the commands above.

The failed standalone preview under `.local/talks-release/standalone-attempt/`
and temporary rendering checks are cleanup candidates; no cleanup was performed.
