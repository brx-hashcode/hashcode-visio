#!/usr/bin/with-contenv bash
# HashCode Meet: the name and tagline in Jitsi's own texts, at each start.
# Mounted at /etc/cont-init.d/20-hashcode-branding (after 10-config).
# The welcome page's title and subtitle come from the translation files, not
# from APP_NAME, so they are rewritten here rather than hidden with CSS.
set -e
cd /usr/share/jitsi-meet

retitle() { # file title subtitle
  [ -f "$1" ] || return 0
  jq --arg t "$2" --arg s "$3" \
    '.welcomepage.headerTitle = $t | (if $s != "" then .welcomepage.headerSubtitle = $s else . end)' \
    "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}

retitle lang/main.json "HashCode Meet" "Simple, secure video meetings, right in your browser."
retitle lang/main-fr.json "HashCode Meet" "Des réunions vidéo simples et sécurisées, directement dans le navigateur."
retitle lang/main-fr-CA.json "HashCode Meet" "Des réunions vidéo simples et sécurisées, directement dans le navigateur."
# Every other language: the name only, its own subtitle.
for f in lang/main-*.json; do
  case "$f" in lang/main-fr.json|lang/main-fr-CA.json) continue ;; esac
  retitle "$f" "HashCode Meet" ""
done

# The installable app (PWA) name and colours.
if [ -f manifest.json ]; then
  jq '.name = "HashCode Meet" | .short_name = "Meet" | .background_color = "#0a0a0a" | .theme_color = "#0a0a0a"' \
    manifest.json > manifest.json.tmp && mv manifest.json.tmp manifest.json
fi

# English is compiled into the app bundle, not read from lang/main.json: the
# welcome page's title and subtitle are patched there too (no-op once done).
B=libs/app.bundle.min.js
sed -i 's/"headerSubtitle":"Secure and high quality meetings","headerTitle":"Jitsi Meet"/"headerSubtitle":"Simple, secure video meetings, right in your browser.","headerTitle":"HashCode Meet"/' "$B"
# The bundle is cached for a year by its ?v=: give the patched one its own
# version, so browsers that kept Jitsi's fetch ours. Bump "hc1" when the patch
# above changes.
grep -q 'app.bundle.min.js?v=[0-9]*hc1"' index.html \
  || sed -i 's/app\.bundle\.min\.js?v=\([0-9]*\)"/app.bundle.min.js?v=\1hc1"/' index.html
