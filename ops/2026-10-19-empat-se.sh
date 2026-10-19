#!/usr/bin/env bash
# Pemasang 19 Okt 2026: 4 SE ikut mulai Oktober (abdurguns1284, Melati1332, AYUMI1336, Rekatiyas1334). Sumber dikunci ke commit f7663f8e089cecade84b17e8c59ce6f62c076390.
R=https://raw.githubusercontent.com/zainalrauf862/svo-ads/f7663f8e089cecade84b17e8c59ce6f62c076390
W=/var/www/tim; O=/opt/svo-ads
# akun_iklan|ID SE|DE|nama akun
DAFTAR='1151924796162812|abdurguns1284|Apdina|SVO APDINA - 04
329024503095673|Melati1332|ZAINAL|SVO MELATI SULITYO - 01
1581542829287239|AYUMI1336|ZAINAL|SVO SEPHIA TRI - 01
1354401445248100|Rekatiyas1334|Miraa|SVO REKA TIYASAYU - 01'

echo "== 0) Cadangan"
B=$O/bak-$(date +%Y%m%d-%H%M%S); mkdir "$B" || exit 1
for f in $O/accounts.json $W/index.html $W/iklan.html; do [ -f "$f" ] && cp -a "$f" "$B"/; done
echo "   tersimpan di $B"

echo "== 1) Cek token bisa membaca 4 akun iklan"
python3 - "$DAFTAR" <<'PY'
import json, sys, urllib.request
T = open('/opt/svo-ads/token.txt').read().strip()
for baris in sys.argv[1].splitlines():
    aid, se, de, nama = baris.split('|')
    req = urllib.request.Request('https://graph.facebook.com/v21.0/act_%s?fields=name,account_status,currency&access_token=%s' % (aid, T))
    try:
        d = json.load(urllib.request.urlopen(req, timeout=60))
        print('   %-14s %s OK | nama: %s | status: %s | %s' % (se, aid, d.get('name'), d.get('account_status'), d.get('currency')))
    except Exception as e:
        print('   %-14s %s BELUM BISA DIBACA (%s) — pastikan akun sudah di-assign ke system user zaratechdasboard' % (se, aid, type(e).__name__))
PY

echo "== 2) Pasang index.html & iklan.html baru (diperiksa dulu)"
pasang() { # $1 file, $2 penanda wajib
  if curl -fsSL --retry 3 "$R/$1" -o "$W/.$1.new" \
     && grep -q "$2" "$W/.$1.new" && tail -c 20 "$W/.$1.new" | grep -q '</html>'; then
    chmod 644 "$W/.$1.new" && mv -f "$W/.$1.new" "$W/$1" && echo "   OK: $1 terpasang"
  else
    rm -f "$W/.$1.new"; echo "   GAGAL: $1 lama TIDAK diubah. Berhenti."; exit 1
  fi
}
pasang index.html "Rekatiyas1334"
pasang iklan.html "AYUMI1336"

echo "== 3) Daftarkan 4 akun iklan ke accounts.json"
python3 - "$DAFTAR" <<'PY'
import json, os, sys
p = '/opt/svo-ads/accounts.json'
a = json.load(open(p, encoding='utf-8'))
for baris in sys.argv[1].splitlines():
    aid, se, de, nama = baris.split('|')
    if aid in a: print('   SUDAH ADA, tidak diubah:', aid, a[aid])
    else: a[aid] = {'se': se, 'de': de, 'produk': ''}; print('   DITAMBAH:', aid, '->', se, '(DE %s)' % de)
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
for se in ('abdurguns1284', 'Melati1332', 'AYUMI1336', 'Rekatiyas1334'):
    a = next((x for x in d['accounts'] if x['se'] == se), None)
    if not a: print('   %-14s TIDAK ADA di data' % se); continue
    p = a['periods']
    t = ' | '.join('%s Rp%s%s' % (k[-2:], format(round(p.get(k, {}).get('spend', 0)), ','), ' GAGAL' if p.get(k, {}).get('gagal') else '') for k in ('2026-08', '2026-09', '2026-10'))
    camp = [c.get('name') for c in a.get('campaigns', []) if c.get('on')][:3]
    print('   %-14s DE %-7s bln %s | campaign aktif hari ini: %s' % (se, a['de'], t, ', '.join(camp) if camp else '-'))
LUAR = {'Saefllh1318', 'JUSTIN1301', 'didaw1328', 'ALKAUTSAR1329', 'abdurguns1284', 'Melati1332', 'AYUMI1336', 'Rekatiyas1334'}
sep = [x for x in d['accounts'] if x['se'] not in LUAR and x['periods'].get('2026-09', {}).get('spend', 0) >= 10000000]
print('   Tab September (perkiraan): %d SE, Rp%s' % (len(sep), format(round(sum(x['periods']['2026-09']['spend'] for x in sep)), ',')))
PY
echo "== Selesai. Buka dashboard lalu tekan Ctrl+Shift+R (atau Cmd+Shift+R)."
