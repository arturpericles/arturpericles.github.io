---
title: Talks
listing:
    id: talks
    contents:
        - talks.yml
    sort: "date desc"
    
    template: talks.ejs
    date-format: MMM. d, YYYY
    sort-ui: false
    filter-ui: true
    field-display-names:
        venue: "Venue"
        type: "Type"
        event: "Event"
        talk: "Talk"
    fields: [title, talk, event, venue, type, date]
    field-links: [event]	
---
:::{#talks}
:::

