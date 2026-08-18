#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/docs"

OLD_PATH="$OUTPUT_DIR/publications/countervailing-platform-power"
NEW_URL="/publications/platform-federalism/"
CANONICAL_URL="https://www.arturpericles.art/publications/platform-federalism/"

mkdir -p "$OLD_PATH"

cat > "$OLD_PATH/index.html" <<HTML
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Redirecting to Platform Federalism</title>
  <meta http-equiv="refresh" content="0; url=$NEW_URL">
  <meta name="robots" content="noindex, follow">
  <link rel="canonical" href="$CANONICAL_URL">
  <script>
    window.location.replace("$NEW_URL");
  </script>
</head>
<body>
  <p>Redirecting to <a href="$NEW_URL">Platform Federalism</a>.</p>
</body>
</html>
HTML

# Keep generated HTML clean so affiliation metadata does not introduce
# trailing whitespace on otherwise blank lines.
find "$OUTPUT_DIR" -type f -name '*.html' -exec perl -pi -e 's/[ \t]+$//' {} +

# Correct two upstream navigation semantics in the generated Quarto markup.
# The first is a native button and must not be exposed as a menu. The second is
# visual sidebar-title text adjacent to the real toggle button, not a second
# navigation landmark or control.
find "$OUTPUT_DIR" -type f -name '*.html' -exec perl -0pi -e '
  s/ role="menu"//g;
  s{<a class="flex-grow-1" role="navigation" data-bs-toggle="collapse" data-bs-target="\.quarto-sidebar-collapse-item" aria-controls="quarto-sidebar" aria-expanded="false" aria-label="Toggle sidebar navigation" onclick="if \(window\.quartoToggleHeadroom\) \{ window\.quartoToggleHeadroom\(\); \}">(.*?)</a>}{<span class="flex-grow-1">$1</span>}gs;
  s{\s*<a class="skip-link" href="#quarto-document-content">Skip to main content</a>\s*}{}g;
  if (index($_, q{id="quarto-document-content"}) >= 0) {
    s{(<body(?:\s[^>]*)?>)}{$1\n<a class="skip-link" href="#quarto-document-content">Skip to main content</a>}s;
    s{(<main\b[^>]*\bid="quarto-document-content")(?![^>]*\btabindex=)}{$1 tabindex="-1"}g;
  }
' {} +
