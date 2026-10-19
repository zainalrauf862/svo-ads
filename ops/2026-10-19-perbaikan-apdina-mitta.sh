#!/usr/bin/env bash
# Pemasang 19 Okt 2026 (menggantikan 2026-10-19-mitta1319.sh — cukup jalankan yang ini):
#  a) Akun iklan David (abdurguns1284) "SVO APDINA - 04": ID yang terdaftar salah satu angka (1151924796162812, ditolak Meta);
#     yang benar 1151914796162812 (terlihat oleh token, status aktif) -> ganti.
#  b) ID SE Mitta J1319 -> Mitta1319 + produk Novia.
# Sumber html dikunci ke commit d058273f40abcf9a9c0849090afdfef4ea09e74f.
R=https://raw.githubusercontent.com/zainalrauf862/svo-ads/d058273f40abcf9a9c0849090afdfef4ea09e74f
W=/var/www/tim; O=/opt/svo-ads
trap 'rm -f "$W/.index.html.new" "$W/.iklan.html.new"' EXIT HUP INT TERM
MITTA=7245155282250490
DAVID_SALAH=1151924796162812; DAVID_BENAR=1151914796162812
# akun_iklan|ID SE yang diharapkan — produk Novia (keputusan BL 19 Okt)
NOVIA='329024503095673|Melati1332
1581542829287239|AYUMI1336
1354401445248100|Rekatiyas1334
1129706771549657|Jessy1333'

echo "== 0) Cadangan"
B=$O/bak-$(date +%Y%m%d-%H%M%S); mkdir "$B" || exit 1
for f in $O/accounts.json $W/index.html $W/iklan.html; do [ -f "$f" ] && cp -a "$f" "$B"/; done
echo "   tersimpan di $B"

echo "== 1) Cek token bisa membaca akun David yang benar"
python3 - "$DAVID_BENAR" <<'PY'
import json, sys, urllib.request, urllib.error
T = open('/opt/svo-ads/token.txt').read().strip(); aid = sys.argv[1]
try:
    d = json.load(urllib.request.urlopen('https://graph.facebook.com/v21.0/act_%s?fields=name,account_status,currency&access_token=%s' % (aid, T), timeout=60))
    print('   %s OK | nama: %s (harusnya: SVO APDINA - 04) | status: %s | %s' % (aid, d.get('name'), d.get('account_status'), d.get('currency')))
except urllib.error.HTTPError as e:
    try: m = json.load(e).get('error', {}).get('message')
    except Exception: m = ''
    print('   %s BELUM BISA DIBACA (HTTP %s: %s)' % (aid, e.code, m))
except Exception as e:
    print('   %s BELUM BISA DIBACA (%s)' % (aid, type(e).__name__))
PY

echo "== 2) Pasang index.html & iklan.html (Mitta1319; keduanya diperiksa dulu, baru dipasang bersamaan)"
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

echo "== 3) accounts.json: akun David diganti ke ID yang benar, Mitta -> Mitta1319, produk Novia"
python3 - "$MITTA" "$DAVID_SALAH" "$DAVID_BENAR" "$NOVIA" <<'PY'
import json, os, sys
p = '/opt/svo-ads/accounts.json'; mitta, salah, benar, novia = sys.argv[1:5]
a = json.load(open(p, encoding='utf-8'))
def pasang(aid, baru, boleh_se):
    v = a.get(aid)
    if v is None: a[aid] = dict(baru); print('   DITAMBAH:', aid, '->', baru); return True
    if v == baru: print('   SUDAH SESUAI, tidak diubah:', aid, v); return True
    if v.get('se') in boleh_se: print('   DIUBAH  :', aid, v, '->', baru); a[aid] = dict(v, **baru); return True
    print('   LEWATI  : akun %s terdaftar atas %s — tidak diubah, kabari Claude' % (aid, v.get('se'))); return False
# a) David
if pasang(benar, {'se': 'abdurguns1284', 'de': 'Apdina', 'produk': 'Novia'}, ('abdurguns1284',)):
    v = a.get(salah)
    if v is None: print('   ID salah', salah, 'sudah tidak terdaftar')
    elif v.get('se') == 'abdurguns1284': a.pop(salah); print('   DIHAPUS : ID salah', salah, v)
    else: print('   LEWATI  : ID', salah, 'terdaftar atas', v.get('se'), '— tidak dihapus')
# b) Mitta
pasang(mitta, {'se': 'Mitta1319', 'de': 'Wahidin', 'produk': 'Novia'}, ('J1319', 'Mitta1319'))
# c) produk Novia (jaga-jaga bila pemasang sebelumnya belum jalan)
for baris in novia.splitlines():
    aid, se = baris.split('|'); v = a.get(aid)
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
print('   diperbarui', d['updated'], '| panggilan gagal:', d.get('gagal'), '(harusnya 0 sekarang) | jumlah SE:', len(d['accounts']))
if any(x['se'] == 'J1319' for x in d['accounts']): print('   PERINGATAN: J1319 masih ada di data (fetch belum jalan, atau masih ada akun lain ber-SE J1319 — lihat langkah 3)')
for se in ('abdurguns1284', 'Mitta1319', 'Melati1332', 'AYUMI1336', 'Rekatiyas1334', 'Jessy1333'):
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
