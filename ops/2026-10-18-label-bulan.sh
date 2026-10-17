#!/usr/bin/env bash
# Pemasang 18 Okt 2026: label bulan program per SE di dashboard iklan. Sumber dikunci ke commit ae18ec7f40e5610bee08f0fc11c66125150ff9d3.
R=https://raw.githubusercontent.com/zainalrauf862/svo-ads/ae18ec7f40e5610bee08f0fc11c66125150ff9d3
W=/var/www/tim; B=/opt/svo-ads/bak-$(date +%Y%m%d-%H%M%S)
mkdir "$B" && cp -a "$W/iklan.html" "$B"/ && echo "cadangan: $B" || exit 1
if curl -fsSL --retry 3 "$R/iklan.html" -o "$W/.iklan.html.new" \
   && grep -q 'function blnTag' "$W/.iklan.html.new" && tail -c 20 "$W/.iklan.html.new" | grep -q '</html>'; then
  chmod 644 "$W/.iklan.html.new" && mv -f "$W/.iklan.html.new" "$W/iklan.html" && echo "OK: iklan.html dengan label bulan terpasang. Buka dashboard lalu Ctrl+Shift+R."
else
  rm -f "$W/.iklan.html.new"; echo "GAGAL: iklan.html lama TIDAK diubah."; exit 1
fi
