#!/usr/bin/env bash
# Pemasang 19 Okt 2026: CV Sephia (AYUMI1336) sudah ada di Drive -> dashboard rekrutmen. Hanya index.html; iklan & akun tidak disentuh. Sumber dikunci ke commit f75b1276c5658bc7b2e1626695060c11b0903275.
R=https://raw.githubusercontent.com/zainalrauf862/svo-ads/f75b1276c5658bc7b2e1626695060c11b0903275
W=/var/www/tim; B=/opt/svo-ads/bak-$(date +%Y%m%d-%H%M%S)
trap 'rm -f "$W/.index.html.new"' EXIT HUP INT TERM
mkdir "$B" && cp -a "$W/index.html" "$B"/ && echo "cadangan: $B" || exit 1
if curl -fsSL --retry 3 "$R/index.html" -o "$W/.index.html.new" \
   && grep -q "1Qb7Dyt6iEga5B2_5x2A_NUqp8eAvVnTo',1,'AYUMI1336'" "$W/.index.html.new" && grep -q "Mitta1319" "$W/.index.html.new" \
   && tail -c 20 "$W/.index.html.new" | grep -q '</html>'; then
  chmod 644 "$W/.index.html.new" && mv -f "$W/.index.html.new" "$W/index.html" && echo "OK: dashboard rekrutmen terbaru terpasang (Sephia: Ada CV). Buka lalu Cmd+Shift+R." || { echo "GAGAL memasang index.html."; exit 1; }
else
  echo "GAGAL: index.html lama TIDAK diubah."; exit 1
fi
