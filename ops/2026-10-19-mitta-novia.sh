#!/usr/bin/env bash
# Pemasang 19 Okt 2026: SE Mitta Paranesti (J1319, DE Wahidin), akun iklan "SVO ADE WAHIDIN - 01" + produk Novia untuk 5 SE. Sumber dikunci ke commit 2207ee8d5970c01e41ee73ac4adcc57347b04c34.
R=https://raw.githubusercontent.com/zainalrauf862/svo-ads/2207ee8d5970c01e41ee73ac4adcc57347b04c34
W=/var/www/tim; O=/opt/svo-ads
MITTA=7245155282250490
# akun_iklan|ID SE yang diharapkan — produk diisi Novia (keputusan BL 19 Okt)
NOVIA='1151924796162812|abdurguns1284
329024503095673|Melati1332
1581542829287239|AYUMI1336
1354401445248100|Rekatiyas1334
1129706771549657|Jessy1333'

echo "== 0) Cadangan"
B=$O/bak-$(date +%Y%m%d-%H%M%S); mkdir "$B" || exit 1
for f in $O/accounts.json $W/index.html $W/iklan.html; do [ -f "$f" ] && cp -a "$f" "$B"/; done
echo "   tersimpan di $B"

echo "== 1) Cek token bisa membaca akun iklan Mitta (dan cek ulang akun David)"
python3 - "$MITTA|J1319 (Mitta)|SVO ADE WAHIDIN - 01" "1151924796162812|abdurguns1284 (David)|SVO APDINA - 04" <<'PY'
import json, sys, urllib.request
T = open('/opt/svo-ads/token.txt').read().strip()
for arg in sys.argv[1:]:
    aid, se, harap = arg.split('|')
    req = urllib.request.Request('https://graph.facebook.com/v21.0/act_%s?fields=name,account_status,currency&access_token=%s' % (aid, T))
    try:
        d = json.load(urllib.request.urlopen(req, timeout=60))
        print('   %-22s %s OK | nama: %s (harusnya: %s) | status: %s | %s' % (se, aid, d.get('name'), harap, d.get('account_status'), d.get('currency')))
    except Exception as e:
        print('   %-22s %s BELUM BISA DIBACA (%s) — pastikan akun sudah di-assign ke system user zaratechdasboard' % (se, aid, type(e).__name__))
PY

echo "== 2) Pasang index.html & iklan.html baru (keduanya diperiksa dulu, baru dipasang bersamaan)"
ambil() { # $1 file, $2 penanda wajib
  curl -fsSL --retry 3 "$R/$1" -o "$W/.$1.new" && grep -q "$2" "$W/.$1.new" && tail -c 20 "$W/.$1.new" | grep -q '</html>'
}
if ambil index.html "J1319" && ambil iklan.html "J1319"; then
  for f in index.html iklan.html; do
    { chmod 644 "$W/.$f.new" && mv -f "$W/.$f.new" "$W/$f" && echo "   OK: $f terpasang"; } || { echo "   GAGAL memasang $f. Berhenti."; exit 1; }
  done
else
  rm -f "$W/.index.html.new" "$W/.iklan.html.new"; echo "   GAGAL: unduhan/pemeriksaan tidak lolos — index.html & iklan.html lama TIDAK diubah. Berhenti."; exit 1
fi

echo "== 3) accounts.json: tambah akun Mitta, isi produk Novia"
python3 - "$MITTA" "$NOVIA" <<'PY'
import json, os, sys
p = '/opt/svo-ads/accounts.json'; mitta = sys.argv[1]
a = json.load(open(p, encoding='utf-8'))
if mitta in a: print('   SUDAH ADA, tidak diubah:', mitta, a[mitta])
else: a[mitta] = {'se': 'J1319', 'de': 'Wahidin', 'produk': ''}; print('   DITAMBAH:', mitta, '-> J1319 (DE Wahidin)')
for baris in sys.argv[2].splitlines():
    aid, se = baris.split('|')
    v = a.get(aid)
    if not v: print('   LEWATI: akun %s (%s) belum terdaftar' % (aid, se)); continue
    if v.get('se') != se: print('   LEWATI: akun %s terdaftar atas %s, bukan %s' % (aid, v.get('se'), se)); continue
    lama = v.get('produk', ''); v['produk'] = 'Novia'
    print('   produk %-14s: %r -> %r' % (se, lama, 'Novia'))
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
for se in ('J1319', 'abdurguns1284', 'Melati1332', 'AYUMI1336', 'Rekatiyas1334', 'Jessy1333'):
    a = next((x for x in d['accounts'] if x['se'] == se), None)
    if not a: print('   %-14s TIDAK ADA di data' % se); continue
    p = a['periods']
    t = ' | '.join('%s Rp%s%s' % (k[-2:], format(round(p.get(k, {}).get('spend', 0)), ','), ' GAGAL' if p.get(k, {}).get('gagal') else '') for k in ('2026-08', '2026-09', '2026-10'))
    print('   %-14s DE %-7s produk %-6s bln %s' % (se, a['de'], a.get('produk') or '-', t))
LUAR = {'Saefllh1318', 'JUSTIN1301', 'didaw1328', 'ALKAUTSAR1329', 'abdurguns1284', 'Melati1332', 'AYUMI1336', 'Rekatiyas1334', 'J1319'}
sep = [x for x in d['accounts'] if x['se'] not in LUAR and (x['periods'].get('2026-09', {}).get('spend', 0) >= 10000000 or x['periods'].get('2026-09', {}).get('gagal'))]
print('   Tab September (perkiraan): %d SE, Rp%s (klaim: 18 SE, Rp559,515,537)' % (len(sep), format(round(sum(x['periods'].get('2026-09', {}).get('spend', 0) for x in sep)), ',')))
PY
echo "== Selesai. Buka dashboard lalu tekan Ctrl+Shift+R (atau Cmd+Shift+R)."
