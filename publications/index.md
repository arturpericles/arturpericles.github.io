---
title: 'Research & Publications'
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
  fields: [title,  date, citation.container-title, citation.status]
  date-format: YYYY
  field-display-names: 
    citation.container-title: ' '
    citation.status: ' '
include-back-link: true
featured: true
---

### Featured

:::{#featured}
:::

### Publications

:::{#publications}
:::


![](/media/blake.jpg)