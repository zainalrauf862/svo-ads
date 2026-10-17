#!/usr/bin/env bash
# Pemasang 17 Okt 2026 — SE DE DENNI1259 (FANDI1326, Rani1243) + aturan September otomatis.
# Jalankan sebagai root di VPS:  bash /tmp/update-denny.sh
# Semua file sumber dikunci ke commit 563cdf2fb56ea082cc2d1d8ccd276ffe17998a76 (isi tidak bisa berubah).
R=https://raw.githubusercontent.com/zainalrauf862/svo-ads/563cdf2fb56ea082cc2d1d8ccd276ffe17998a76
W=/var/www/tim; O=/opt/svo-ads

echo "== 0) Cadangan"
B=$O/bak-$(date +%Y%m%d-%H%M%S); mkdir "$B" || exit 1
for f in $O/accounts.json $O/history.json $O/fetch.py $W/index.html $W/iklan.html $W/data.json; do
  [ -f "$f" ] && cp -a "$f" "$B"/
done
echo "   tersimpan di $B"

echo "== 1) Cek token bisa membaca 3 akun iklan baru"
python3 - <<'PY'
import json, urllib.request
T = open('/opt/svo-ads/token.txt').read().strip()
for aid, se in [('897087610056697', 'FANDI1326 (As2)'), ('957320094077018', 'Rani1243 (BGS JOS ID)'), ('921348747032296', 'Rani1243 (C)')]:
    req = urllib.request.Request('https://graph.facebook.com/v21.0/act_%s?fields=name,account_status,currency' % aid,
                                 headers={'Authorization': 'Bearer ' + T})
    try:
        d = json.load(urllib.request.urlopen(req, timeout=60))
        print('   %-22s %s OK  | nama: %s | status: %s | %s' % (se, aid, d.get('name'), d.get('account_status'), d.get('currency')))
    except Exception as e:
        body = e.read().decode('utf-8', 'replace')[:160] if hasattr(e, 'read') else ''
        print('   %-22s %s BELUM BISA DIBACA -> %s %s' % (se, aid, e, body))
PY

echo "== 2) Pasang versi baru index.html, iklan.html, fetch.py (diperiksa dulu sebelum mengganti)"
ok=1
curl -fsSL --retry 3 "$R/index.html" -o "$W/.index.html.new" || ok=0
curl -fsSL --retry 3 "$R/iklan.html" -o "$W/.iklan.html.new" || ok=0
curl -fsSL --retry 3 "$R/fetch.py"   -o "$O/.fetch.py.new"   || ok=0
if [ $ok = 1 ] && grep -q TGL_VERIF "$W/.index.html.new" && grep -q MIN_BELANJA "$W/.iklan.html.new" \
   && grep -q 'gagal=1' "$O/.fetch.py.new" && python3 -m py_compile "$O/.fetch.py.new" \
   && tail -c 20 "$W/.index.html.new" | grep -q '</html>' && tail -c 20 "$W/.iklan.html.new" | grep -q '</html>'; then
  chmod 644 "$W/.index.html.new" "$W/.iklan.html.new"
  mv -f "$W/.index.html.new" "$W/index.html" && mv -f "$W/.iklan.html.new" "$W/iklan.html" && mv -f "$O/.fetch.py.new" "$O/fetch.py"
  echo "   OK: 3 file versi baru terpasang"
else
  rm -f "$W/.index.html.new" "$W/.iklan.html.new" "$O/.fetch.py.new"
  echo "   GAGAL: file lama TIDAK diubah. Berhenti di sini."; exit 1
fi

echo "== 3) Daftarkan 3 akun iklan baru ke accounts.json"
python3 - <<'PY'
import json, os
p = '/opt/svo-ads/accounts.json'
a = json.load(open(p, encoding='utf-8'))
baru = {
  '897087610056697': {'se': 'FANDI1326', 'de': 'Denni', 'produk': ''},
  '957320094077018': {'se': 'Rani1243',  'de': 'Denni', 'produk': ''},
  '921348747032296': {'se': 'Rani1243',  'de': 'Denni', 'produk': ''},
}
for k, v in baru.items():
    if k in a: print('   SUDAH ADA, tidak diubah:', k, a[k])
    else: a[k] = v; print('   DITAMBAH:', k, '->', v['se'])
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
LUAR = {'Saefllh1318', 'JUSTIN1301', 'didaw1328'}; MIN = 10000000
by = {a['se']: a for a in d['accounts']}
for se in ['FANDI1326', 'Rani1243', 'ALKAUTSAR1329', 'FebrianaEkaPutri1315', 'BayuAditia1311']:
    a = by.get(se)
    if not a: print('   %-21s TIDAK ADA di data' % se); continue
    s9 = a['periods'].get('2026-09', {}); s10 = a['periods'].get('2026-10', {})
    ket = 'DATA GAGAL DITARIK' if s9.get('gagal') else ('tampil di September' if s9.get('spend', 0) >= MIN and se not in LUAR else 'mulai Oktober')
    print('   %-21s Sep Rp%13s (%3s order)  Okt Rp%13s  -> %s' % (se, format(round(s9.get('spend', 0)), ','), s9.get('order', 0), format(round(s10.get('spend', 0)), ','), ket))
sep = [a for a in d['accounts'] if a['se'] not in LUAR and (a['periods'].get('2026-09', {}).get('spend', 0) >= MIN or a['periods'].get('2026-09', {}).get('gagal'))]
print('   Tab September: %d SE, total Rp%s' % (len(sep), format(round(sum(a['periods']['2026-09'].get('spend', 0) for a in sep)), ',')))
PY
echo "== Selesai. Buka dashboard lalu tekan Ctrl+Shift+R (atau Cmd+Shift+R) supaya halaman baru termuat."
