#!/usr/bin/env bash
# Pemasang 19 Okt 2026: ID SE Mitta J1319 -> Mitta1319 (username Globemerce, dari BL) + produk Novia untuk Mitta. Sumber dikunci ke commit d058273f40abcf9a9c0849090afdfef4ea09e74f.
R=https://raw.githubusercontent.com/zainalrauf862/svo-ads/d058273f40abcf9a9c0849090afdfef4ea09e74f
W=/var/www/tim; O=/opt/svo-ads
trap 'rm -f "$W/.index.html.new" "$W/.iklan.html.new"' EXIT HUP INT TERM
MITTA=7245155282250490
# akun_iklan|ID SE yang diharapkan — produk Novia (keputusan BL 19 Okt); diulang di sini supaya aman bila pemasang sebelumnya belum jalan
NOVIA='1151924796162812|abdurguns1284
329024503095673|Melati1332
1581542829287239|AYUMI1336
1354401445248100|Rekatiyas1334
1129706771549657|Jessy1333'

echo "== 0) Cadangan"
B=$O/bak-$(date +%Y%m%d-%H%M%S); mkdir "$B" || exit 1
for f in $O/accounts.json $W/index.html $W/iklan.html; do [ -f "$f" ] && cp -a "$f" "$B"/; done
echo "   tersimpan di $B"

echo "== 1) Cek ulang akun iklan David (sebelumnya selalu gagal ditarik)"
python3 - "1151924796162812|abdurguns1284 (David)|SVO APDINA - 04" <<'PY'
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
ambil() { # $1 file — wajib berisi Mitta1319, tidak boleh lagi memakai kunci 'J1319', utuh sampai </html>
  curl -fsSL --retry 3 "$R/$1" -o "$W/.$1.new" && grep -q "Mitta1319" "$W/.$1.new" \
    && ! grep -q "'J1319'" "$W/.$1.new" && tail -c 20 "$W/.$1.new" | grep -q '</html>'
}
if ambil index.html && ambil iklan.html; then
  for f in index.html iklan.html; do
    { chmod 644 "$W/.$f.new" && mv -f "$W/.$f.new" "$W/$f" && echo "   OK: $f terpasang"; } || { echo "   GAGAL memasang $f. Berhenti."; exit 1; }
  done
else
  rm -f "$W/.index.html.new" "$W/.iklan.html.new"; echo "   GAGAL: unduhan/pemeriksaan tidak lolos — index.html & iklan.html lama TIDAK diubah. Berhenti."; exit 1
fi

echo "== 3) accounts.json: akun Mitta -> Mitta1319, produk Novia"
python3 - "$MITTA" "$NOVIA" <<'PY'
import json, os, sys
p = '/opt/svo-ads/accounts.json'; mitta = sys.argv[1]
a = json.load(open(p, encoding='utf-8'))
baru = {'se': 'Mitta1319', 'de': 'Wahidin', 'produk': 'Novia'}
v = a.get(mitta)
if v is None:
    a[mitta] = baru; print('   DITAMBAH:', mitta, '->', baru)
elif v == baru:
    print('   SUDAH SESUAI, tidak diubah:', mitta, v)
elif v.get('se') in ('J1319', 'Mitta1319'):
    print('   DIUBAH  :', mitta, v, '->', baru); a[mitta] = dict(v, **baru)
else:
    print('   LEWATI  : akun %s terdaftar atas %s (bukan J1319/Mitta1319) — tidak diubah, kabari Claude' % (mitta, v.get('se')))
for baris in sys.argv[2].splitlines():
    aid, se = baris.split('|')
    v = a.get(aid)
    if not v: print('   LEWATI: akun %s (%s) belum terdaftar' % (aid, se)); continue
    if v.get('se') != se: print('   LEWATI: akun %s terdaftar atas %s, bukan %s' % (aid, v.get('se'), se)); continue
    if v.get('produk') != 'Novia': print('   produk %-14s: %r -> %r' % (se, v.get('produk', ''), 'Novia')); v['produk'] = 'Novia'
sisa = [k for k, x in a.items() if x.get('se') == 'J1319']
if sisa: print('   PERINGATAN: masih ada akun ber-SE J1319:', sisa)
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
if any(x['se'] == 'J1319' for x in d['accounts']): print('   PERINGATAN: J1319 masih ada di data (fetch belum jalan, atau masih ada akun lain ber-SE J1319 — lihat langkah 3)')
for se in ('Mitta1319', 'abdurguns1284', 'Melati1332', 'AYUMI1336', 'Rekatiyas1334', 'Jessy1333'):
    a = next((x for x in d['accounts'] if x['se'] == se), None)
    if not a: print('   %-14s TIDAK ADA di data' % se); continue
    p = a['periods']
    t = ' | '.join('%s Rp%s%s' % (k[-2:], format(round(p.get(k, {}).get('spend', 0)), ','), ' GAGAL' if p.get(k, {}).get('gagal') else '') for k in ('2026-08', '2026-09', '2026-10'))
    print('   %-14s DE %-7s produk %-6s bln %s' % (se, a['de'], a.get('produk') or '-', t))
LUAR = {'Saefllh1318', 'JUSTIN1301', 'didaw1328', 'ALKAUTSAR1329', 'abdurguns1284', 'Melati1332', 'AYUMI1336', 'Rekatiyas1334', 'Mitta1319'}
sep = [x for x in d['accounts'] if x['se'] not in LUAR and (x['periods'].get('2026-09', {}).get('spend', 0) >= 10000000 or x['periods'].get('2026-09', {}).get('gagal'))]
print('   Tab September (perkiraan): %d SE, Rp%s (klaim: 18 SE, Rp559,515,537)' % (len(sep), format(round(sum(x['periods'].get('2026-09', {}).get('spend', 0) for x in sep)), ',')))
PY
echo "== Selesai. Buka dashboard lalu tekan Ctrl+Shift+R (atau Cmd+Shift+R)."
