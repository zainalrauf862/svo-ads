#!/usr/bin/env bash
# Pemasang 27 Nov 2026: klaim Oktober sudah diajukan -> bulan Oktober dicoret di label 31 SE peserta (dashboard iklan).
# Hanya iklan.html; index.html, kantor.json, accounts.json, dan data tidak disentuh. Sumber dikunci ke commit 390a851927e8713b71dae588232a23f5fc50d567.
R=https://raw.githubusercontent.com/zainalrauf862/svo-ads/390a851927e8713b71dae588232a23f5fc50d567
W=/var/www/tim
trap 'rm -f "$W/.iklan.html.new"' EXIT
trap 'echo "DIBATALKAN (Ctrl+C) — tidak ada yang diubah."; exit 130' HUP INT TERM
B=/opt/svo-ads/bak-$(date +%Y%m%d-%H%M%S); mkdir "$B" && cp -a "$W/iklan.html" "$B"/ && echo "cadangan: $B" || exit 1
if curl -fsSL --retry 3 "$R/iklan.html" -o "$W/.iklan.html.new" \
   && grep -q "'2026-10':CLAIM_OKT" "$W/.iklan.html.new" && grep -q "function namaSE" "$W/.iklan.html.new" \
   && tail -c 20 "$W/.iklan.html.new" | grep -q '</html>'; then
  { chmod 644 "$W/.iklan.html.new" && mv -f "$W/.iklan.html.new" "$W/iklan.html" && echo "OK: iklan.html terpasang"; } || { echo "GAGAL memasang iklan.html. Berhenti."; exit 1; }
  echo "Selesai. Buka dashboard iklan lalu tekan Cmd+Shift+R: bulan Oktober tercoret pada 31 SE peserta klaim."
else
  rm -f "$W/.iklan.html.new"; echo "GAGAL: unduhan/pemeriksaan tidak lolos — iklan.html lama TIDAK diubah."; exit 1
fi
