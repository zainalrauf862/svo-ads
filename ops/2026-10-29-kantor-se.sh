#!/usr/bin/env bash
# Pemasang 29 Okt 2026: kantor asal SE (Kaliurang / Wonosobo / Umbulharjo) tampil di dashboard iklan dan di tabel performa rekrutmen.
# Memasang kantor.json (baru), index.html, iklan.html. index.html ini sekaligus membawa perbaikan CV Jenita (28 Okt).
# accounts.json, data.json, dan fetch.py tidak disentuh. Sumber dikunci ke commit 225ce791f23b233b87a4470fc5c00260c454369c.
R=https://raw.githubusercontent.com/zainalrauf862/svo-ads/225ce791f23b233b87a4470fc5c00260c454369c
W=/var/www/tim
trap 'rm -f "$W/.kantor.json.new" "$W/.index.html.new" "$W/.iklan.html.new"' EXIT
trap 'echo "DIBATALKAN (Ctrl+C) — tidak ada yang diubah."; exit 130' HUP INT TERM
B=/opt/svo-ads/bak-$(date +%Y%m%d-%H%M%S); mkdir "$B" && cp -a "$W/index.html" "$W/iklan.html" "$B"/ && echo "cadangan: $B" || exit 1
ambil() { # $1 file, $2 penanda wajib
  curl -fsSL --retry 3 "$R/$1" -o "$W/.$1.new" && grep -q "$2" "$W/.$1.new" && tail -c 20 "$W/.$1.new" | grep -q '</html>'
}
if curl -fsSL --retry 3 "$R/kantor.json" -o "$W/.kantor.json.new" \
   && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert len(d["se"])==34' "$W/.kantor.json.new" \
   && ambil index.html "ktrCell" && grep -q "CV Jenita" "$W/.index.html.new" \
   && ambil iklan.html "ktrTag"; then
  for f in kantor.json index.html iklan.html; do
    { chmod 644 "$W/.$f.new" && mv -f "$W/.$f.new" "$W/$f" && echo "OK: $f terpasang"; } || { echo "GAGAL memasang $f. Berhenti."; exit 1; }
  done
  echo "Selesai. Buka dashboard lalu tekan Cmd+Shift+R: label kantor (Kaliurang/Wonosobo/Umbulharjo) muncul di samping nama 34 SE."
else
  rm -f "$W/.kantor.json.new" "$W/.index.html.new" "$W/.iklan.html.new"; echo "GAGAL: unduhan/pemeriksaan tidak lolos — dashboard lama TIDAK diubah."; exit 1
fi
