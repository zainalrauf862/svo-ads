#!/usr/bin/env bash
# Pemasang 27 Okt 2026: klaim September sudah diajukan -> bulan September dicoret di label 18 SE peserta (dashboard iklan).
# Hanya index.html & iklan.html; accounts.json dan data tidak disentuh. Sumber dikunci ke commit bd58b7b6e013d533da96425e67a9fc28f7438707.
R=https://raw.githubusercontent.com/zainalrauf862/svo-ads/bd58b7b6e013d533da96425e67a9fc28f7438707
W=/var/www/tim
trap 'rm -f "$W/.index.html.new" "$W/.iklan.html.new"' EXIT
trap 'echo "DIBATALKAN (Ctrl+C) — tidak ada yang diubah."; exit 130' HUP INT TERM
B=/opt/svo-ads/bak-$(date +%Y%m%d-%H%M%S); mkdir "$B" && cp -a "$W/index.html" "$W/iklan.html" "$B"/ && echo "cadangan: $B" || exit 1
ambil() { # $1 file, $2 penanda wajib
  curl -fsSL --retry 3 "$R/$1" -o "$W/.$1.new" && grep -q "$2" "$W/.$1.new" && tail -c 20 "$W/.$1.new" | grep -q '</html>'
}
if ambil index.html "AQLI1842 baru 27 Okt" && ambil iklan.html "'2026-09':CLAIM_SEP"; then
  for f in index.html iklan.html; do
    { chmod 644 "$W/.$f.new" && mv -f "$W/.$f.new" "$W/$f" && echo "OK: $f terpasang"; } || { echo "GAGAL memasang $f. Berhenti."; exit 1; }
  done
  echo "Selesai. Buka dashboard iklan lalu tekan Cmd+Shift+R: bulan September tercoret pada 18 SE peserta klaim."
else
  rm -f "$W/.index.html.new" "$W/.iklan.html.new"; echo "GAGAL: unduhan/pemeriksaan tidak lolos — index.html & iklan.html lama TIDAK diubah."; exit 1
fi
