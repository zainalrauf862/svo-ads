#!/usr/bin/env bash
# Pemasang 19 Okt 2026: hasil sapu Drive (DE MIRAA1391, kandidat Melati & Sephia). Sumber dikunci ke commit e3e549bfc10393540233bda12c180a00b36b7054.
R=https://raw.githubusercontent.com/zainalrauf862/svo-ads/e3e549bfc10393540233bda12c180a00b36b7054
W=/var/www/tim; B=/opt/svo-ads/bak-$(date +%Y%m%d-%H%M%S)
mkdir "$B" && cp -a "$W/index.html" "$B"/ && echo "cadangan: $B" || exit 1
if curl -fsSL --retry 3 "$R/index.html" -o "$W/.index.html.new" \
   && grep -q "MIRAA1391" "$W/.index.html.new" && tail -c 20 "$W/.index.html.new" | grep -q '</html>'; then
  chmod 644 "$W/.index.html.new" && mv -f "$W/.index.html.new" "$W/index.html" && echo "OK: dashboard rekrutmen terbaru terpasang. Buka lalu Ctrl+Shift+R."
else
  rm -f "$W/.index.html.new"; echo "GAGAL: index.html lama TIDAK diubah."; exit 1
fi
