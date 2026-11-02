#!/usr/bin/env bash
# Pemasang 2 Nov 2026: 4 kandidat SE baru (Gloria, Ubaidillah, Hafid, Hakam) + CV Bayu Rahmanto, kartu periode rekrutmen "Selesai".
# Hanya index.html (halaman rekrutmen); iklan.html, kantor.json, accounts.json, dan data tidak disentuh. Sumber dikunci ke commit 971014097513d454134c3896647c2dd081cd41f6.
R=https://raw.githubusercontent.com/zainalrauf862/svo-ads/971014097513d454134c3896647c2dd081cd41f6
W=/var/www/tim
trap 'rm -f "$W/.index.html.new"' EXIT
trap 'echo "DIBATALKAN (Ctrl+C) — tidak ada yang diubah."; exit 130' HUP INT TERM
B=/opt/svo-ads/bak-$(date +%Y%m%d-%H%M%S); mkdir "$B" && cp -a "$W/index.html" "$B"/ && echo "cadangan: $B" || exit 1
if curl -fsSL --retry 3 "$R/index.html" -o "$W/.index.html.new" \
   && grep -q "Hakam Umam Thoriq" "$W/.index.html.new" && grep -q "ktrCell" "$W/.index.html.new" \
   && tail -c 20 "$W/.index.html.new" | grep -q '</html>'; then
  { chmod 644 "$W/.index.html.new" && mv -f "$W/.index.html.new" "$W/index.html" && echo "OK: index.html terpasang"; } || { echo "GAGAL memasang index.html. Berhenti."; exit 1; }
  echo "Selesai. Buka dashboard rekrutmen lalu tekan Cmd+Shift+R: 40 kandidat, 37 CV, 34 ID, data 2 Nov 2026, periode 'Selesai'."
else
  rm -f "$W/.index.html.new"; echo "GAGAL: unduhan/pemeriksaan tidak lolos — index.html lama TIDAK diubah."; exit 1
fi
