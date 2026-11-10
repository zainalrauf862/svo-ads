#!/usr/bin/env bash
# Pemasang 10 Nov 2026: akun iklan Ubaidillah Sulthon (sulthon1287, DE Apdina) — "SVO APDINA - 02" 1063402785940854,
# ID yang benar dari DE Apdina (10 Nov). Aturan SE ini (kantor Wonosobo, tidak dihitung September, Oktober hanya bila
# >= Rp10 jt) sudah ada di dashboard; pemasang ini hanya mendaftarkan akunnya di accounts.json lalu menarik data.
# Langkah 1 menjawab belanja Oktober akun ini. Halaman dashboard (html) tidak disentuh. Token tidak pernah dicetak.
W=/var/www/tim; O=/opt/svo-ads
trap 'echo "   DIBATALKAN (Ctrl+C) — langkah berikutnya tidak dijalankan."; exit 130' HUP INT TERM
# akun_iklan|ID SE|DE|nama akun yang diharapkan
DAFTAR='1063402785940854|sulthon1287|Apdina|SVO APDINA - 02'

echo "== 0) Cadangan"
B=$O/bak-$(date +%Y%m%d-%H%M%S); mkdir "$B" || exit 1
cp -a $O/accounts.json "$B"/ || exit 1
echo "   tersimpan di $B"

echo "== 1) Cek token bisa membaca akun iklan Ubaidillah + belanja Oktober 2026 (langsung dari Meta)"
python3 - "$DAFTAR" <<'PY'
import json, sys, urllib.request, urllib.error, urllib.parse
T = open('/opt/svo-ads/token.txt').read().strip()
G = 'https://graph.facebook.com/v21.0/act_%s%s?%s'
def ambil(aid, path, q):
    q = dict(q, access_token=T)
    return json.load(urllib.request.urlopen(G % (aid, path, urllib.parse.urlencode(q)), timeout=60))
for baris in sys.argv[1].splitlines():
    aid, se, de, harap = baris.split('|')
    try:
        d = ambil(aid, '', {'fields': 'name,account_status,currency'})
        ins = ambil(aid, '/insights', {'fields': 'spend', 'level': 'account',
                                      'time_range': json.dumps({'since': '2026-10-01', 'until': '2026-10-31'})})
        okt = sum(float(r.get('spend', 0)) for r in ins.get('data', []))
        hasil = 'CUKUP >= Rp10 jt -> ikut OKTOBER' if okt >= 10000000 else 'KURANG dari Rp10 jt -> mulai NOVEMBER'
        print('   %-5s %-16s %s (harusnya: %s) | status %s %s | belanja Oktober Rp%s | %s'
              % (se, aid, d.get('name'), harap, d.get('account_status'), d.get('currency'), format(round(okt), ','), hasil))
    except urllib.error.HTTPError as e:
        try: m = json.load(e).get('error', {}).get('message')
        except Exception: m = ''
        print('   %-5s %-16s BELUM BISA DIBACA (HTTP %s: %s)' % (se, aid, e.code, m))
    except Exception as e:
        print('   %-5s %-16s BELUM BISA DIBACA (%s)' % (se, aid, type(e).__name__))
PY

echo "== 2) Daftarkan akun iklan ke accounts.json (produk Novia)"
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

echo "== 3) Tarik data sekarang (menunggu bila jadwal otomatis sedang jalan, maks 10 menit)"
/usr/bin/flock -w 600 -E 75 /run/svo-ads.lock /usr/bin/python3 $O/fetch.py 2>&1 | tee -a /var/log/svo-ads.log; rc=${PIPESTATUS[0]}
[ "$rc" = 0 ] && echo "   fetch OK" || echo "   FETCH GAGAL (kode $rc; 75 = jadwal otomatis masih jalan, ulangi sebentar lagi)"

echo "== 4) Ringkasan dari data dashboard"
python3 - <<'PY'
import json
d = json.load(open('/var/www/tim/data.json', encoding='utf-8'))
print('   diperbarui', d['updated'], '| panggilan gagal:', d.get('gagal'), '| jumlah SE:', len(d['accounts']))
for se in ('sulthon1287',):
    a = next((x for x in d['accounts'] if x['se'] == se), None)
    if not a: print('   %-5s TIDAK ADA di data' % se); continue
    p = a['periods']; okt = p.get('2026-10', {}); nov = p.get('2026-11', {})
    mulai = 'belum pasti (data Oktober gagal)' if okt.get('gagal') else ('OKTOBER' if okt.get('spend', 0) >= 10000000 else 'NOVEMBER')
    print('   %-5s DE %-7s | Oktober Rp%s | November s/d hari ini Rp%s | dihitung mulai %s'
          % (se, a['de'], format(round(okt.get('spend', 0)), ','), format(round(nov.get('spend', 0)), ','), mulai))
PY
echo "== Selesai. Buka dashboard lalu tekan Cmd+Shift+R."
