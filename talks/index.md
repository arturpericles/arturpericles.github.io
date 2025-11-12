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

![Sybil Andrews, *The New Cable*, 1931, Internet Archive](/media/andrews-new-cable.webp){fig-alt="LLM-created description verified by Art: A dynamic, stylized print of three muscular workers, rendered in reddish-brown, hauling a thick, massive cable. Their bodies are bent in unison along a strong diagonal line, conveying a powerful sense of rhythmic, collective labor."}