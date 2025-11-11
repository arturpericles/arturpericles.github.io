---
listing:
  - id: talks
    contents:
        - talks.yml
    sort: "date desc"
    template: talks.ejs
    date-format: MMM. d, YYYY
    sort-ui: false
    filter-ui: false
    field-display-names:
        venue: "Venue"
        type: "Type"
        event: "Event"
        talk: "Talk"
    fields: [title, talk, event, venue, type, date]
    field-links: [event]	    
  - id: conferences
    contents:
        - conferences.yml
    sort: "date desc"
    template: talks.ejs
    date-format: MMM. d, YYYY
    sort-ui: false
    filter-ui: false
    field-display-names:
        venue: "Venue"
        type: "Type"
        event: "Event"
        talk: "Talk"
    fields: [title, talk, event, venue, type, date]
    field-links: [event]
format: 
  html: 
    page-layout: full
    pagetitle: Talks    	
---

::::: {layout-ncol=2}

::: {#first-column}

## Paper Presentations

:::{#conferences}
:::

:::

::: {#second-column}

## Talks & Panels 


:::{#talks}
:::

:::
:::::