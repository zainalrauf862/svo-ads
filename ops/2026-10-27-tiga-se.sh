#!/usr/bin/env bash
# Pemasang 27 Okt 2026: 3 SE ikut mulai Oktober — edoofr1308 (Edo Farid Rukmana, DE Safuan), Jack1335 (Mokhammad
# Aunurrofiq, DE Aqli / AQLI1842), Jenita1321 (Jenita, DE Hendri); produk Novia. Sumber html dikunci ke commit 316469c3d4d61cb009f44b7d965c9168f112ac11.
R=https://raw.githubusercontent.com/zainalrauf862/svo-ads/316469c3d4d61cb009f44b7d965c9168f112ac11
W=/var/www/tim; O=/opt/svo-ads
trap 'rm -f "$W/.index.html.new" "$W/.iklan.html.new"' EXIT
trap 'echo "   DIBATALKAN (Ctrl+C) — langkah berikutnya tidak dijalankan."; exit 130' HUP INT TERM
# akun_iklan|ID SE|DE|nama akun yang diharapkan
DAFTAR='941953904179080|edoofr1308|Safuan|SVO EDO FARID - 01
344783838057154|Jack1335|Aqli|SVO AQLI QORIB -06
1593066148121462|Jenita1321|Hendri|SVO HENDRI 01'

echo "== 0) Cadangan"
B=$O/bak-$(date +%Y%m%d-%H%M%S); mkdir "$B" || exit 1
for f in $O/accounts.json $W/index.html $W/iklan.html; do [ -f "$f" ] && cp -a "$f" "$B"/; done
echo "   tersimpan di $B"

echo "== 1) Cek token bisa membaca 3 akun iklan"
python3 - "$DAFTAR" <<'PY'
import json, sys, urllib.request, urllib.error
T = open('/opt/svo-ads/token.txt').read().strip()
for baris in sys.argv[1].splitlines():
    aid, se, de, harap = baris.split('|')
    try:
        d = json.load(urllib.request.urlopen('https://graph.facebook.com/v21.0/act_%s?fields=name,account_status,currency&access_token=%s' % (aid, T), timeout=60))
        print('   %-11s %s OK | nama: %s (harusnya: %s) | status: %s | %s' % (se, aid, d.get('name'), harap, d.get('account_status'), d.get('currency')))
    except urllib.error.HTTPError as e:
        try: m = json.load(e).get('error', {}).get('message')
        except Exception: m = ''
        print('   %-11s %s BELUM BISA DIBACA (HTTP %s: %s)' % (se, aid, e.code, m))
    except Exception as e:
        print('   %-11s %s BELUM BISA DIBACA (%s)' % (se, aid, type(e).__name__))
PY

echo "== 2) Pasang index.html & iklan.html baru (keduanya diperiksa dulu, baru dipasang bersamaan)"
ambil() { # $1 file, $2 penanda wajib
  curl -fsSL --retry 3 "$R/$1" -o "$W/.$1.new" && grep -q "$2" "$W/.$1.new" && tail -c 20 "$W/.$1.new" | grep -q '</html>'
}
if ambil index.html "AQLI1842" && ambil iklan.html "Jenita1321"; then
  for f in index.html iklan.html; do
    { chmod 644 "$W/.$f.new" && mv -f "$W/.$f.new" "$W/$f" && echo "   OK: $f terpasang"; } || { echo "   GAGAL memasang $f. Berhenti."; exit 1; }
  done
else
  rm -f "$W/.index.html.new" "$W/.iklan.html.new"; echo "   GAGAL: unduhan/pemeriksaan tidak lolos — index.html & iklan.html lama TIDAK diubah. Berhenti."; exit 1
fi

echo "== 3) Daftarkan 3 akun iklan ke accounts.json (produk Novia)"
python3 - "$DAFTAR" <<'PY'
import json, os, sys
p = '/opt/svo-ads/accounts.json'
a = json.load(open(p, encoding='utf-8'))
for baris in sys.argv[1].splitlines():
    aid, se, de, harap = baris.split('|')
    baru = {'se': se, 'de': de, 'produk': 'Novia'}
    v = a.get(aid)
    if v is None: a[aid] = baru; print('   DITAMBAH:', aid, '->', baru)
    elif v == baru: print('   SUDAH SESUAI, tidak diubah:', aid, v)
    elif v.get('se') == se: print('   DIUBAH  :', aid, v, '->', baru); a[aid] = dict(v, **baru)
    else: print('   LEWATI  : akun %s terdaftar atas %s (bukan %s) — tidak diubah, kabari Claude' % (aid, v.get('se'), se))
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
for se in ('edoofr1308', 'Jack1335', 'Jenita1321'):
    a = next((x for x in d['accounts'] if x['se'] == se), None)
    if not a: print('   %-11s TIDAK ADA di data' % se); continue
    p = a['periods']
    t = ' | '.join('%s Rp%s%s' % (k[-2:], format(round(p.get(k, {}).get('spend', 0)), ','), ' GAGAL' if p.get(k, {}).get('gagal') else '') for k in ('2026-08', '2026-09', '2026-10'))
    camp = [c.get('name') for c in a.get('campaigns', []) if c.get('on')][:3]
    print('   %-11s DE %-6s produk %-6s bln %s | campaign aktif: %s' % (se, a['de'], a.get('produk') or '-', t, ', '.join(camp) if camp else '-'))
LUAR = {'Saefllh1318', 'JUSTIN1301', 'didaw1328', 'ALKAUTSAR1329', 'abdurguns1284', 'Melati1332', 'AYUMI1336',
        'Rekatiyas1334', 'Mitta1319', 'edoofr1308', 'Jack1335', 'Jenita1321'}
sep = [x for x in d['accounts'] if x['se'] not in LUAR and (x['periods'].get('2026-09', {}).get('spend', 0) >= 10000000 or x['periods'].get('2026-09', {}).get('gagal'))]
print('   Tab September (perkiraan): %d SE, Rp%s (klaim: 18 SE, Rp559,515,537)' % (len(sep), format(round(sum(x['periods'].get('2026-09', {}).get('spend', 0) for x in sep)), ',')))
PY
echo "== Selesai. Buka dashboard lalu tekan Ctrl+Shift+R (atau Cmd+Shift+R)."
