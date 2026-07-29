---
listing:
- id: publications
  contents: 
    - "**/index.qmd"
    - "**/index.markdown"
    - "**/index.md"
  sort: "date desc"
  categories: false
  sort-ui: false
  filter-ui: false
  fields: [title,  date, citation.container-title, citation.publisher, citation.status]
  date-format: YYYY
  template: publications.ejs            
  field-display-names: 
    citation.container-title: Venue
- id: featured
  contents: 
    - "**/index.qmd"
    - "**/index.markdown"
    - "**/index.md"
  type: grid
  template: featured.ejs
  template-params:
    grid-columns: 3
  include:
    featured: true
  sort: "date desc"
  categories: false
  sort-ui: false
  filter-ui: false
  fields: [title, title-short, date, citation.container-title, citation.status]
  date-format: YYYY
  field-display-names: 
    citation.container-title: ' '
    citation.status: ' '
include-back-link: true
featured: true
format: 
  html: 
    page-layout: article
    pagetitle: Publications
---



# Highlights

:::{#featured}
:::

# Publications

:::{#publications}
:::

![William Blake, _Europe. A Prophecy_ (frontispiece), ca. 1820, Yale Center for British Art](/media/blake.webp){fig-alt="Description of another copy by the British Museum: a bearded nude male (probably Urizen) crouching in a heavenly sphere, its light partially covered by clouds; his left arm holding a pair of compasses and reaching down with them, measuring the surrounding darkness."}