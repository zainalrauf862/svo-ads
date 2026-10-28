#!/usr/bin/env bash
# Pemasang 28 Okt 2026: CV Jenita (Jenita1321, DE HENDRI1551) sudah ada di Drive -> dashboard rekrutmen diperbarui.
# Hanya index.html; iklan.html, accounts.json, dan data tidak disentuh. Sumber dikunci ke commit 435a325fd2b69b02c178e217d581acfb169386f5.
R=https://raw.githubusercontent.com/zainalrauf862/svo-ads/435a325fd2b69b02c178e217d581acfb169386f5
W=/var/www/tim
trap 'rm -f "$W/.index.html.new"' EXIT
trap 'echo "DIBATALKAN (Ctrl+C) — tidak ada yang diubah."; exit 130' HUP INT TERM
B=/opt/svo-ads/bak-$(date +%Y%m%d-%H%M%S); mkdir "$B" && cp -a "$W/index.html" "$B"/ && echo "cadangan: $B" || exit 1
if curl -fsSL --retry 3 "$R/index.html" -o "$W/.index.html.new" \
   && grep -q "CV Jenita" "$W/.index.html.new" && tail -c 20 "$W/.index.html.new" | grep -q '</html>'; then
  { chmod 644 "$W/.index.html.new" && mv -f "$W/.index.html.new" "$W/index.html" && echo "OK: index.html terpasang"; } || { echo "GAGAL memasang index.html. Berhenti."; exit 1; }
  echo "Selesai. Buka dashboard rekrutmen lalu tekan Cmd+Shift+R: CV Jenita tercentang, CV 32, lengkap 32, data 28 Okt 2026."
else
  rm -f "$W/.index.html.new"; echo "GAGAL: unduhan/pemeriksaan tidak lolos — index.html lama TIDAK diubah."; exit 1
fi
