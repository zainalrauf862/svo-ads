#!/usr/bin/env bash
# Cek 19 Okt 2026 (HANYA MEMBACA, tidak mengubah apa pun): apakah token dashboard sudah bisa membaca akun iklan David "SVO APDINA - 04".
python3 - <<'PY'
import json, urllib.request, urllib.parse, urllib.error
T = open('/opt/svo-ads/token.txt').read().strip()
AID = '1151924796162812'
G = 'https://graph.facebook.com/v21.0/'
def get(path, **q):
    q['access_token'] = T
    for coba in range(3):   # ulangi bila jaringan tersendat (bukan bila Meta menolak)
        try:
            return json.load(urllib.request.urlopen(G + path + '?' + urllib.parse.urlencode(q), timeout=60)), None
        except urllib.error.HTTPError as e:
            try: err = json.load(e).get('error', {})
            except Exception: err = {}
            return None, 'HTTP %s | kode %s/%s | %s' % (e.code, err.get('code'), err.get('error_subcode'), err.get('message'))
        except Exception as e:
            gagal = type(e).__name__
    return None, gagal + ' (jaringan)'

print('== 1) Info akun %s (harusnya: SVO APDINA - 04)' % AID)
d, e = get('act_' + AID, fields='name,account_status,disable_reason,currency')
print('   ', ('BISA DIBACA: %s | status %s | %s' % (d.get('name'), d.get('account_status'), d.get('currency'))) if d else 'BELUM BISA DIBACA: ' + e)

print('== 2) Belanja per bulan')
for since, until in (('2026-08-01', '2026-08-31'), ('2026-09-01', '2026-09-30'), ('2026-10-01', '2026-10-31')):
    d, e = get('act_%s/insights' % AID, fields='spend', time_range=json.dumps({'since': since, 'until': until}))
    if d: print('    %s Rp%s' % (since[:7], format(round(float(d['data'][0]['spend'])) if d.get('data') else 0, ',')))
    else: print('    %s GAGAL: %s' % (since[:7], e))

print('== 3) Akun berisi "APDINA" yang terlihat oleh token dashboard')
q = {'fields': 'name,account_id,account_status', 'limit': 200}; semua = []; daftar_ok = True
while True:
    d, e = get('me/adaccounts', **q)
    if not d: print('    gagal membaca daftar akun:', e); daftar_ok = False; break
    semua += d.get('data', [])
    nxt = d.get('paging', {}).get('next'); aft = d.get('paging', {}).get('cursors', {}).get('after')
    if not (nxt and aft): break
    q['after'] = aft
print('    total akun yang bisa dibaca token:', len(semua))
ada = False
for x in semua:
    if 'APDINA' in (x.get('name') or '').upper() or x.get('account_id') == AID:
        ada = True; print('    %s | %s | status %s%s' % (x.get('account_id'), x.get('name'), x.get('account_status'), '  <- akun David' if x.get('account_id') == AID else ''))
if daftar_ok and not ada: print('    (tidak ada akun APDINA sama sekali)')
acc = json.load(open('/opt/svo-ads/accounts.json', encoding='utf-8'))
print('    terdaftar di dashboard:', AID, '->', acc.get(AID))
PY
