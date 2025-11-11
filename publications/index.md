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
  fields: [title,  date, citation.container-title, citation.status]
  date-format: YYYY
  field-display-names: 
    citation.container-title: ' '
    citation.status: ' '
include-back-link: true
featured: true
format: 
  html: 
    page-layout: full
    pagetitle: Publications
    css: sticky.css 
---


::::: {layout="[[60,-5,45], [100]]"} 

::: {#first-column}

# Highlights

:::{#featured}
:::

# Publications

:::{#publications}
:::

:::

::: {#second-column .sticky-column}


![William Blake, _Europe. A Prophecy_ (frontispiece), ca. 1820, Yale Center for British Art](/media/blake.webp)


:::

:::::