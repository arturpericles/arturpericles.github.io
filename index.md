---
title: |
 Artur Pericles\
 L. Monteiro
subtitle: "Law & technology scholar at Yale"
pagetitle: 'Artur Pericles L. Monteiro'
toc: false
about: 
  template: solana
  image-width: 36em
  image: /media/seymour-march.webp
  image-title: 'Robert Seymour, The March of Intellect (detail), ca. 1828, The British Museum'
  image-alt: 'Description from the British Museum: "Satire against corruption: a huge automaton representing the new London University (later University College, London) tramples over greedy clerics, doctors, lawyers and the crown. c.1828 Hand-coloured etching."'
  id: hero-heading
  links:
    - text: "{{< fa brands mastodon >}}"
      aria-label: Mastodon
      href: https://mastodon.social/@artp
    - text: "{{< fa brands bluesky >}}"
      aria-label: Bluesky
      href: https://bsky.app/profile/arturpericles.art
    - text: "{{< fa brands linkedin >}}"
      aria-label: LinkedIn
      href: https://www.linkedin.com/in/arturpericles/
    - text: "{{< fa envelope >}}"
      aria-label: Email
      href: mailto:artur.monteiro@yale.edu
    - text: "{{< fa key>}}"
      aria-label: PGP Key
      href: https://keys.openpgp.org/vks/v1/by-fingerprint/F6E4B34C3B2C537DC1DBF3FB41B9B8C46C9F6B37
format: 
  html: 
    page-layout: full
    include-after-body:
      - text: |
          <script>
          document.addEventListener("DOMContentLoaded", function() {
            
            // 1. Find the original image
            const img = document.querySelector("img.about-image");
            
            if (img && img.title) {
              
              // 2. Create the new caption element
              const caption = document.createElement("figcaption");
              caption.textContent = img.title;
              caption.classList.add("mycaption");

              // 3. Create a <figure> to wrap them
              const figure = document.createElement("figure");
              
              // 4. Replace the <img> with the new <figure>
              //    (This keeps it in the same grid position)
              img.parentElement.replaceChild(figure, img);
              
              // 5. Move the <img> *inside* the <figure>
              figure.appendChild(img);
              
              // 6. Add the caption *inside* the <figure>
              figure.appendChild(caption);
            }
          });
          </script>

header-includes: >
  <link rel="stylesheet" href="assets/index.css">
resources:
  - assets/index.css
---


::: {#hero-heading}
[Learn more about me &rarr;](/about/){.about-links .subtitle}
:::
<!-- hero-heading -->

<a href="https://mastodon.social/@artp" rel="me"></a>







