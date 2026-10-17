#!/usr/bin/env bash
# Pemasang 17 Okt 2026 (2): ALKAUTSAR1329 mulai Oktober + produk Novia untuk SE DE DENNI1259.
# Sumber dikunci ke commit da306d8f883ad7fd95fd0f9fa17f6eeeec5d5fd7.
R=https://raw.githubusercontent.com/zainalrauf862/svo-ads/da306d8f883ad7fd95fd0f9fa17f6eeeec5d5fd7
W=/var/www/tim; O=/opt/svo-ads

echo "== 0) Cadangan"
B=$O/bak-$(date +%Y%m%d-%H%M%S); mkdir "$B" || exit 1
for f in $O/accounts.json $W/iklan.html; do [ -f "$f" ] && cp -a "$f" "$B"/; done
echo "   tersimpan di $B"

echo "== 1) Pasang iklan.html baru (diperiksa dulu)"
if curl -fsSL --retry 3 "$R/iklan.html" -o "$W/.iklan.html.new" \
   && grep -q "'didaw1328','ALKAUTSAR1329'" "$W/.iklan.html.new" && tail -c 20 "$W/.iklan.html.new" | grep -q '</html>'; then
  chmod 644 "$W/.iklan.html.new" && mv -f "$W/.iklan.html.new" "$W/iklan.html" && echo "   OK: iklan.html terpasang"
else
  rm -f "$W/.iklan.html.new"; echo "   GAGAL: iklan.html lama TIDAK diubah. Berhenti."; exit 1
fi

echo "== 2) Isi produk Novia untuk 4 akun DE Denni (ALKAUTSAR1329, FANDI1326, Rani1243 x2)"
python3 - <<'PY'
import json, os
p = '/opt/svo-ads/accounts.json'
a = json.load(open(p, encoding='utf-8'))
for k in ['1019976770354555', '897087610056697', '957320094077018', '921348747032296']:
    if k not in a: print('   TIDAK ADA di accounts.json:', k); continue
    lama = a[k].get('produk', ''); a[k]['produk'] = 'Novia'
    print('   %s %-14s produk: %r -> Novia' % (k, a[k]['se'], lama))
with open(p + '.tmp', 'w', encoding='utf-8') as f:
    json.dump(a, f, ensure_ascii=False, indent=1); f.flush(); os.fsync(f.fileno())
assert json.load(open(p + '.tmp', encoding='utf-8')) == a
os.replace(p + '.tmp', p)
PY

echo "== 3) Tarik data sekarang (menunggu bila jadwal otomatis sedang jalan, maks 10 menit)"
/usr/bin/flock -w 600 -E 75 /run/svo-ads.lock /usr/bin/python3 $O/fetch.py 2>&1 | tee -a /var/log/svo-ads.log; rc=${PIPESTATUS[0]}
[ "$rc" = 0 ] && echo "   fetch OK" || echo "   FETCH GAGAL (kode $rc; 75 = jadwal otomatis masih jalan, ulangi sebentar lagi)"

echo "== 4) Ringkasan"
python3 - <<'PY'
import json
d = json.load(open('/var/www/tim/data.json', encoding='utf-8'))
print('   diperbarui', d['updated'], '| panggilan gagal:', d.get('gagal'))
for a in d['accounts']:
    if a['se'] in ('ALKAUTSAR1329', 'FANDI1326', 'Rani1243'):
        print('   %-14s produk: %s' % (a['se'], a.get('produk') or '(kosong)'))
LUAR = {'Saefllh1318', 'JUSTIN1301', 'didaw1328', 'ALKAUTSAR1329'}; MIN = 10000000
sep = [a for a in d['accounts'] if a['se'] not in LUAR and (a['periods'].get('2026-09', {}).get('spend', 0) >= MIN or a['periods'].get('2026-09', {}).get('gagal'))]
print('   Tab September: %d SE, total Rp%s (klaim: 18 SE, Rp559,515,537)' % (len(sep), format(round(sum(a['periods']['2026-09'].get('spend', 0) for a in sep)), ',')))
PY
echo "== Selesai. Buka dashboard lalu tekan Ctrl+Shift+R (atau Cmd+Shift+R)."
