#!/usr/bin/env bash
# Pemasang 2 Nov 2026 sore: 2 SE baru (akun iklan masuk BM 2 Nov) — J1313 Bagus Kresna Djatmiko (DE Dayat, kantor Kaliurang)
# & J1324 Bayu Rahmanto (DE Renaldo, kantor Umbulharjo); produk Novia. Sudah termasuk nama lengkap 4 SE sebelumnya.
# Langkah 1 juga menjawab: berapa belanja Oktober tiap akun dan apakah >= Rp10 jt (>= 10 jt ikut Oktober, kurang -> mulai November).
# Sumber html/kantor.json dikunci ke commit 0ddc29901eb22128c5b0e92a9cd5f75526662ee3. Token tidak pernah dicetak.
R=https://raw.githubusercontent.com/zainalrauf862/svo-ads/0ddc29901eb22128c5b0e92a9cd5f75526662ee3
W=/var/www/tim; O=/opt/svo-ads
trap 'rm -f "$W/.kantor.json.new" "$W/.index.html.new" "$W/.iklan.html.new"' EXIT
trap 'echo "   DIBATALKAN (Ctrl+C) — langkah berikutnya tidak dijalankan."; exit 130' HUP INT TERM
# akun_iklan|ID SE|DE|nama akun yang diharapkan
DAFTAR='1361207184433718|J1313|Dayat|svo kresna -01
749921700453674|J1324|Renaldo|SVO RENALDO - 01'

echo "== 0) Cadangan"
B=$O/bak-$(date +%Y%m%d-%H%M%S); mkdir "$B" || exit 1
for f in $O/accounts.json $W/index.html $W/iklan.html $W/kantor.json; do [ -f "$f" ] && cp -a "$f" "$B"/; done
echo "   tersimpan di $B"

echo "== 1) Cek token bisa membaca 2 akun iklan + belanja Oktober 2026 (langsung dari Meta)"
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

echo "== 2) Pasang kantor.json, index.html & iklan.html baru (semuanya diperiksa dulu, baru dipasang)"
ambil() { # $1 file, $2 penanda wajib
  curl -fsSL --retry 3 "$R/$1" -o "$W/.$1.new" && grep -q "$2" "$W/.$1.new" && tail -c 20 "$W/.$1.new" | grep -q '</html>'
}
if curl -fsSL --retry 3 "$R/kantor.json" -o "$W/.kantor.json.new" \
   && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert len(d["se"])==40 and d["se"]["J1324"]=="Umbulharjo" and d["nama"]["J1313"]=="Bagus Kresna Djatmiko"' "$W/.kantor.json.new" \
   && ambil index.html "DAYAT1216':\[\['Bagus Kresna" && ambil iklan.html "'J1313':10000000"; then
  for f in kantor.json index.html iklan.html; do
    { chmod 644 "$W/.$f.new" && mv -f "$W/.$f.new" "$W/$f" && echo "   OK: $f terpasang"; } || { echo "   GAGAL memasang $f. Berhenti."; exit 1; }
  done
else
  rm -f "$W/.kantor.json.new" "$W/.index.html.new" "$W/.iklan.html.new"; echo "   GAGAL: unduhan/pemeriksaan tidak lolos — dashboard lama TIDAK diubah. Berhenti."; exit 1
fi

echo "== 3) Daftarkan 2 akun iklan ke accounts.json (produk Novia)"
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

echo "== 5) Ringkasan dari data dashboard"
python3 - <<'PY'
import json
d = json.load(open('/var/www/tim/data.json', encoding='utf-8'))
print('   diperbarui', d['updated'], '| panggilan gagal:', d.get('gagal'), '| jumlah SE:', len(d['accounts']))
for se in ('J1313', 'J1324'):
    a = next((x for x in d['accounts'] if x['se'] == se), None)
    if not a: print('   %-5s TIDAK ADA di data' % se); continue
    p = a['periods']; okt = p.get('2026-10', {}); nov = p.get('2026-11', {})
    mulai = 'belum pasti (data Oktober gagal)' if okt.get('gagal') else ('OKTOBER' if okt.get('spend', 0) >= 10000000 else 'NOVEMBER')
    print('   %-5s DE %-7s | Oktober Rp%s | November s/d hari ini Rp%s | dihitung mulai %s'
          % (se, a['de'], format(round(okt.get('spend', 0)), ','), format(round(nov.get('spend', 0)), ','), mulai))
PY
echo "== Selesai. Buka dashboard lalu tekan Cmd+Shift+R."
