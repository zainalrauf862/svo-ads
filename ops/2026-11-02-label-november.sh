#!/usr/bin/env bash
# Pemasang 2 Nov 2026: label bulan (November, Desember, Januari) untuk Tri Putra, Aditya, Indra, Daru (belum belanja).
# Hanya iklan.html; index.html, kantor.json, accounts.json, dan data tidak disentuh. Sumber dikunci ke commit d66cf3f008acfce01c371dcad9666736e15ee138.
R=https://raw.githubusercontent.com/zainalrauf862/svo-ads/d66cf3f008acfce01c371dcad9666736e15ee138
W=/var/www/tim
trap 'rm -f "$W/.iklan.html.new"' EXIT
trap 'echo "DIBATALKAN (Ctrl+C) — tidak ada yang diubah."; exit 130' HUP INT TERM
B=/opt/svo-ads/bak-$(date +%Y%m%d-%H%M%S); mkdir "$B" && cp -a "$W/iklan.html" "$B"/ && echo "cadangan: $B" || exit 1
if curl -fsSL --retry 3 "$R/iklan.html" -o "$W/.iklan.html.new" \
   && grep -q "'J1342':'2026-11'" "$W/.iklan.html.new" && grep -q "function namaSE" "$W/.iklan.html.new" \
   && tail -c 20 "$W/.iklan.html.new" | grep -q '</html>'; then
  { chmod 644 "$W/.iklan.html.new" && mv -f "$W/.iklan.html.new" "$W/iklan.html" && echo "OK: iklan.html terpasang"; } || { echo "GAGAL memasang iklan.html. Berhenti."; exit 1; }
  echo "Selesai. Buka dashboard iklan lalu tekan Cmd+Shift+R: Tri Putra, Aditya, Indra, Daru berlabel (November, Desember, Januari)."
else
  rm -f "$W/.iklan.html.new"; echo "GAGAL: unduhan/pemeriksaan tidak lolos — iklan.html lama TIDAK diubah."; exit 1
fi
