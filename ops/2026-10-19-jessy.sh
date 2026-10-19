#!/usr/bin/env bash
# Pemasang 19 Okt 2026: SE Jessy1333 (DE DAUS1615), akun iklan "SVO UUS - 02". Sumber dikunci ke commit 22c097a4b648533bb2896357de84d849a48ab4d3.
R=https://raw.githubusercontent.com/zainalrauf862/svo-ads/22c097a4b648533bb2896357de84d849a48ab4d3
W=/var/www/tim; O=/opt/svo-ads; AKUN=1129706771549657

echo "== 0) Cadangan"
B=$O/bak-$(date +%Y%m%d-%H%M%S); mkdir "$B" || exit 1
for f in $O/accounts.json $W/index.html; do [ -f "$f" ] && cp -a "$f" "$B"/; done
echo "   tersimpan di $B"

echo "== 1) Cek token bisa membaca akun iklan Jessy"
python3 - "$AKUN" <<'PY'
import json, sys, urllib.request
T = open('/opt/svo-ads/token.txt').read().strip(); aid = sys.argv[1]
req = urllib.request.Request('https://graph.facebook.com/v21.0/act_%s?fields=name,account_status,currency&access_token=%s' % (aid, T))
try:
    d = json.load(urllib.request.urlopen(req, timeout=60))
    print('   %s OK | nama: %s | status: %s | %s' % (aid, d.get('name'), d.get('account_status'), d.get('currency')))
except Exception as e:
    print('   %s BELUM BISA DIBACA (%s) — pastikan akun sudah di-assign ke system user zaratechdasboard' % (aid, type(e).__name__))
PY

echo "== 2) Pasang index.html baru (diperiksa dulu)"
if curl -fsSL --retry 3 "$R/index.html" -o "$W/.index.html.new" \
   && grep -q "Jessy1333" "$W/.index.html.new" && tail -c 20 "$W/.index.html.new" | grep -q '</html>'; then
  chmod 644 "$W/.index.html.new" && mv -f "$W/.index.html.new" "$W/index.html" && echo "   OK: index.html terpasang"
else
  rm -f "$W/.index.html.new"; echo "   GAGAL: index.html lama TIDAK diubah. Berhenti."; exit 1
fi

echo "== 3) Daftarkan akun iklan Jessy ke accounts.json"
python3 - "$AKUN" <<'PY'
import json, os, sys
p = '/opt/svo-ads/accounts.json'; aid = sys.argv[1]
a = json.load(open(p, encoding='utf-8'))
if aid in a: print('   SUDAH ADA, tidak diubah:', a[aid])
else: a[aid] = {'se': 'Jessy1333', 'de': 'Daus', 'produk': ''}; print('   DITAMBAH:', aid, '-> Jessy1333 (DE Daus)')
with open(p + '.tmp', 'w', encoding='utf-8') as f:
    json.dump(a, f, ensure_ascii=False, indent=1); f.flush(); os.fsync(f.fileno())
assert json.load(open(p + '.tmp', encoding='utf-8')) == a
os.replace(p + '.tmp', p); print('   total akun:', len(a))
PY

echo "== 4) Tarik data sekarang (menunggu bila jadwal otomatis sedang jalan, maks 10 menit)"
/usr/bin/flock -w 600 -E 75 /run/svo-ads.lock /usr/bin/python3 $O/fetch.py 2>&1 | tee -a /var/log/svo-ads.log; rc=${PIPESTATUS[0]}
[ "$rc" = 0 ] && echo "   fetch OK" || echo "   FETCH GAGAL (kode $rc; 75 = jadwal otomatis masih jalan, ulangi sebentar lagi)"

echo "== 5) Ringkasan"
python3 - <<'PY'
import json
d = json.load(open('/var/www/tim/data.json', encoding='utf-8'))
print('   diperbarui', d['updated'], '| panggilan gagal:', d.get('gagal'), '| jumlah SE:', len(d['accounts']))
a = next((x for x in d['accounts'] if x['se'] == 'Jessy1333'), None)
if not a: print('   Jessy1333 TIDAK ADA di data')
else:
    p = a['periods']
    for k in ('2026-08', '2026-09', '2026-10'):
        m = p.get(k, {}); print('   Jessy1333 %s: Rp%s · %s order%s' % (k, format(round(m.get('spend', 0)), ','), m.get('order', 0), ' · GAGAL DITARIK' if m.get('gagal') else ''))
    s9 = p.get('2026-09', {}).get('spend', 0)
    print('   -> September', 'Rp10 jt ke atas: AKAN TAMPIL di tab September (kabari Claude)' if s9 >= 10000000 else 'di bawah Rp10 jt: mulai Oktober')
PY
echo "== Selesai. Buka dashboard lalu tekan Ctrl+Shift+R (atau Cmd+Shift+R)."
