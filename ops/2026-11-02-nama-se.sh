#!/usr/bin/env bash
# Pemasang 2 Nov 2026: nama lengkap tampil untuk J1342, J1343, J1285, J1345 (sebelumnya hanya ID).
# Hanya kantor.json, index.html, iklan.html; accounts.json, data.json, fetch.py tidak disentuh. Sumber dikunci ke commit 9dc0250bb47aab9b4eceb00748a806409abe0175.
R=https://raw.githubusercontent.com/zainalrauf862/svo-ads/9dc0250bb47aab9b4eceb00748a806409abe0175
W=/var/www/tim
trap 'rm -f "$W/.kantor.json.new" "$W/.index.html.new" "$W/.iklan.html.new"' EXIT
trap 'echo "DIBATALKAN (Ctrl+C) — tidak ada yang diubah."; exit 130' HUP INT TERM
B=/opt/svo-ads/bak-$(date +%Y%m%d-%H%M%S); mkdir "$B" && cp -a "$W/kantor.json" "$W/index.html" "$W/iklan.html" "$B"/ && echo "cadangan: $B" || exit 1
ambil() { # $1 file, $2 penanda wajib
  curl -fsSL --retry 3 "$R/$1" -o "$W/.$1.new" && grep -q "$2" "$W/.$1.new" && tail -c 20 "$W/.$1.new" | grep -q '</html>'
}
if curl -fsSL --retry 3 "$R/kantor.json" -o "$W/.kantor.json.new" \
   && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert len(d["se"])==38 and d["nama"]["J1342"]=="Tri Putra Satria Jati"' "$W/.kantor.json.new" \
   && ambil index.html "function namaSE" && ambil iklan.html "function namaSE"; then
  for f in kantor.json index.html iklan.html; do
    { chmod 644 "$W/.$f.new" && mv -f "$W/.$f.new" "$W/$f" && echo "OK: $f terpasang"; } || { echo "GAGAL memasang $f. Berhenti."; exit 1; }
  done
  echo "Selesai. Buka dashboard lalu tekan Cmd+Shift+R: Tri Putra Satria Jati, Aditya Alfian Darmawan, Indra Sukmana, Daru Sosetyoning Pamuncak tampil dengan namanya."
else
  rm -f "$W/.kantor.json.new" "$W/.index.html.new" "$W/.iklan.html.new"; echo "GAGAL: unduhan/pemeriksaan tidak lolos — dashboard lama TIDAK diubah."; exit 1
fi
