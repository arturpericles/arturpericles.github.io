---
title: | 
 Artur Pericles
 L. Monteiro
subtitle: "Law & technology scholar at Yale"
toc: false
about: 
  template: solana
  image-width: 36em
  image: media/seymour-march.jpg
  image-title: 'Robert Seymour, The March of Intellect, c. 1828, The British Museum'
  id: hero-heading
  links:
    - text: |
        <a href="https://mastodon.social/@artp" rel="me" aria-label="Mastodon">
        <i class="fa-brands fa-mastodon" role="img" aria-hidden="true"></i>
        </a>
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
            // Find the image by its class
            const img = document.querySelector("img.about-image");
            
            // If we find the image and it has a title (from image-title)
            if (img && img.title) {
              
              // Create a new <figcaption> element
              const caption = document.createElement("figcaption");
              
              // Set its text to the image's title
              caption.textContent = img.title;
              
              // Add a class for styling
              caption.classList.add("mycaption");
              
              // Insert the caption after the image's <div> container
              img.parentElement.insertAdjacentElement("afterend", caption);
            }
          });
          </script>

header-includes: >
  <link rel="stylesheet" href="assets/index.css">
resources:
  - assets/index.css
---

<br><br><br><br><br><br>

::: {#hero-heading}
[Learn more about me &rarr;](/about/){.about-links .subtitle}
:::
<!-- hero-heading -->



