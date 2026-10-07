#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SVO Ads — tarik data Meta Ads semua akun -> /var/www/tim/data.json
Dijalankan berkala (cron) di VPS. Token dibaca dari file token.txt (tidak pernah masuk kode).
Stdlib only (tanpa pip).
"""
import json, os, sys, urllib.parse, urllib.request, datetime, calendar

BASE = "https://graph.facebook.com/v21.0"
DIR = os.path.dirname(os.path.abspath(__file__))
OUTDIR = "/var/www/tim"

TOKEN = open(os.path.join(DIR, "token.txt")).read().strip()
try:
    ACC = json.load(open(os.path.join(DIR, "accounts.json")))  # {id: {se,de,produk}}
except Exception:
    ACC = {}

# Periode harian memakai preset relatif (selalu "sekarang").
PERIODS = {"harian": "today", "kemarin": "yesterday"}

# Periode bulanan TIDAK boleh pakai preset relatif (this_month/last_month): begitu
# ganti bulan, data bulan lama ikut hilang dari dashboard. Jadi tiap bulan kalender
# ditarik memakai time_range absolut, mulai dari bulan pertama program.
BULAN_MULAI = (2026, 8)                      # Agustus 2026 = bulan pertama Program Subsidi Rekrutmen SE
HIST_FILE = os.path.join(DIR, "history.json")  # cache bulan yang sudah tutup buku
HIST_VER = 2   # struktur entri cache berubah: {"until":..., "m":{...}}
ID_BLN = ["Januari", "Februari", "Maret", "April", "Mei", "Juni",
          "Juli", "Agustus", "September", "Oktober", "November", "Desember"]
FIELDS = "spend,impressions,reach,frequency,clicks,inline_link_clicks,ctr,cpc,actions,action_values,purchase_roas"

# Pemetaan action_type Meta -> tahap funnel (best-effort; dikalibrasi dari _debug_actions.json)
# Pemetaan event Meta -> funnel, SAMA dengan pull_novia.py (ambil action_type PERTAMA yg cocok)
# Catatan: "Klik WA" = Add to Cart; "Contact" = event custom pixel Novia.
MAP = {
    "viewlp":   ["landing_page_view", "omni_landing_page_view"],
    "klikwa":   ["add_to_cart", "offsite_conversion.fb_pixel_add_to_cart", "onsite_web_add_to_cart"],
    "purchase": ["omni_purchase", "purchase", "offsite_conversion.fb_pixel_purchase"],
}

# Contact = "chat/lead benar-benar masuk". Tiap SE pakai funnel berbeda:
#  - funnel WhatsApp  -> onsite_conversion.messaging_conversation_started_7d
#  - funnel web/pixel -> offsite_conversion.fb_pixel_custom
#  - funnel lead form -> lead / fb_pixel_lead
# Karena itu diambil NILAI TERBESAR di antara kandidat (bukan yang pertama ketemu),
# supaya akun WA tidak terbaca 0 hanya karena event pixel-nya kebetulan ada sedikit.
CONTACT_KEYS = [
    "onsite_conversion.messaging_conversation_started_7d",
    "offsite_conversion.fb_pixel_custom",
    "offsite_conversion.fb_pixel_lead",
    "onsite_conversion.lead",
    "onsite_web_lead",
    "lead",
]
_seen = set()
_contact_dbg = {}   # {ad_account_id: {action_type: value}} untuk periode bulan lalu
_gagal = [0]        # berapa panggilan insight yang gagal pada putaran ini


def api(path, params):
    p = dict(params); p["access_token"] = TOKEN
    url = BASE + path + "?" + urllib.parse.urlencode(p)
    req = urllib.request.Request(url, headers={"User-Agent": "svo-ads"})
    with urllib.request.urlopen(req, timeout=90) as r:
        return json.load(r)


def fnum(x, d=0.0):
    try:
        return float(x)
    except Exception:
        return d


def actval(items, keys):
    """Ambil nilai dari action_type PERTAMA (urut prioritas) yang ada — hindari dobel-hitung
    ketika Meta melaporkan 1 konversi yang sama di beberapa alias (purchase/omni_purchase/dst)."""
    if not items:
        return 0
    idx = {}
    for a in items:
        t = a.get("action_type")
        if t:
            _seen.add(t)
            if t not in idx:
                idx[t] = a
    for k in keys:
        if k in idx:
            return int(round(fnum(idx[k].get("value"))))
    return 0


def actvalf(items, keys):
    """Sama seperti actval tapi kembalikan float (untuk ROAS dari purchase_roas)."""
    if not items:
        return 0.0
    idx = {}
    for a in items:
        t = a.get("action_type")
        if t and t not in idx:
            idx[t] = a
    for k in keys:
        if k in idx:
            return fnum(idx[k].get("value"))
    return 0.0


def actpair(items, vals, keys):
    """Ambil JUMLAH dan NILAI dari action_type yang SAMA.

    Sebelumnya jumlah diambil dari `actions` dan nilai dari `action_values` lewat dua panggilan
    actval() terpisah. Kedua array itu tidak selalu memuat alias yang sama, sehingga jumlah bisa
    terambil dari satu alias sementara nilainya dari alias lain — pasangan yang tidak sepadan.
    Kasus nyata: SVO BAYU ADITIA - 01 September 2026 terbaca 146 order senilai Rp13.860.000,
    padahal Rp13.860.000 tepat 14 x Rp990.000 dan ROAS yang dilaporkan Meta 1,19 hanya cocok
    dengan 14 order. Karena itu alias yang ada di KEDUA array selalu diutamakan."""
    ia, iv = {}, {}
    for x in (items or []):
        t = x.get("action_type")
        if t:
            _seen.add(t)
            ia.setdefault(t, int(round(fnum(x.get("value")))))
    for x in (vals or []):
        t = x.get("action_type")
        if t:
            iv.setdefault(t, fnum(x.get("value")))
    for k in keys:                      # alias yang jumlah DAN nilainya sama-sama ada
        if k in ia and k in iv:
            return ia[k], int(round(iv[k]))
    for k in keys:                      # tidak ada pasangan utuh -> apa adanya
        if k in ia:
            return ia[k], int(round(iv.get(k, 0)))
    return 0, 0


def actbreak(items, keys):
    """Nilai tiap action_type kandidat yang benar-benar ada (untuk debug & max)."""
    idx = {}
    for x in (items or []):
        t = x.get("action_type")
        if t:
            _seen.add(t)
            if t not in idx:
                idx[t] = int(round(fnum(x.get("value"))))
    return {k: idx[k] for k in keys if k in idx}


def actmax(items, keys):
    b = actbreak(items, keys)
    return max(b.values()) if b else 0


def metrics(row):
    a = row.get("actions"); av = row.get("action_values")
    spend = fnum(row.get("spend"))
    order, value = actpair(a, av, MAP["purchase"])
    klik = int(fnum(row.get("inline_link_clicks"))) or actval(a, ["link_click"])
    roas = round(actvalf(row.get("purchase_roas"), MAP["purchase"]), 2)
    if not roas and spend:
        roas = round(value / spend, 2)
    if order and value and (value / order) < 300000:
        print("PERINGATAN mutu data: %d order senilai %d -> hanya %d per order, periksa alias event."
              % (order, value, value // order), file=sys.stderr)
    return {
        "spend": int(round(spend)),
        "impresi": int(fnum(row.get("impressions"))),
        "reach": int(fnum(row.get("reach"))),
        "frekuensi": round(fnum(row.get("frequency")), 2),
        "klik": klik,
        "ctr": round(fnum(row.get("ctr")), 2),
        "cpc": int(round(fnum(row.get("cpc")))),
        "viewlp": actval(a, MAP["viewlp"]),
        "klikwa": actval(a, MAP["klikwa"]),
        "contact": actmax(a, CONTACT_KEYS),
        "order": order,
        "value": value,
        "roas": roas,
    }


def acct_period(aid, preset):
    try:
        d = api("/act_%s/insights" % aid, {"date_preset": preset, "fields": FIELDS, "level": "account"})
        data = d.get("data", [])
        return metrics(data[0]) if data else metrics({})
    except Exception:
        _gagal[0] += 1
        return metrics({})


def acct_range(aid, since, until, dbg=False):
    """Insight satu rentang tanggal absolut (dipakai untuk tiap bulan kalender).
    Kembalikan (metrik, sukses). sukses=False berarti API gagal — angka nol di sini
    TIDAK boleh masuk cache, supaya bulan itu dicoba lagi putaran berikutnya.
    data kosong (akun belum ada di bulan itu) tetap sukses: nol-nya memang benar."""
    try:
        d = api("/act_%s/insights" % aid, {
            "time_range": json.dumps({"since": since, "until": until}),
            "fields": FIELDS, "level": "account"})
        data = d.get("data", [])
        if not data:
            return metrics({}), True
        if dbg:   # rekam rincian kandidat contact utk verifikasi
            _contact_dbg[aid] = actbreak(data[0].get("actions"), CONTACT_KEYS)
        return metrics(data[0]), True
    except Exception:
        _gagal[0] += 1
        return metrics({}), False


def bulan_bulan(now):
    """Daftar bulan kalender BULAN_MULAI s/d bulan berjalan (urut lama -> baru)."""
    out = []
    y, m = BULAN_MULAI
    while (y, m) <= (now.year, now.month):
        berjalan = (y, m) == (now.year, now.month)
        until = now.strftime("%Y-%m-%d") if berjalan else \
                "%04d-%02d-%02d" % (y, m, calendar.monthrange(y, m)[1])
        out.append({"key": "%04d-%02d" % (y, m),
                    "label": "%s %d" % (ID_BLN[m - 1], y),
                    "since": "%04d-%02d-01" % (y, m),
                    "until": until,
                    "current": berjalan})
        m += 1
        if m > 12:
            m, y = 1, y + 1
    return out


def tulis_json(path, obj):
    """Tulis atomik: isi file sementara lalu rename. Pembaca selalu melihat berkas utuh —
    kalau proses mati di tengah, data.json lama tetap utuh, bukan terpotong."""
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(obj, f, ensure_ascii=False)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)


def load_hist():
    """Cache bulan-bulan lama supaya tidak ditarik ulang tiap 30 menit selamanya."""
    try:
        h = json.load(open(HIST_FILE))
        if h.get("_v") == HIST_VER:
            return h
    except Exception:
        pass
    return {"_v": HIST_VER}


def campaign_status(aid):
    m = {}
    try:
        d = api("/act_%s/campaigns" % aid, {"fields": "id,effective_status", "limit": 500})
        for c in d.get("data", []):
            m[c["id"]] = c.get("effective_status")
    except Exception:
        pass
    return m


def campaigns_today(aid):
    status = campaign_status(aid)
    out = []
    try:
        d = api("/act_%s/insights" % aid, {
            "date_preset": "today", "level": "campaign",
            "fields": "campaign_id,campaign_name," + FIELDS, "limit": 500})
        for row in d.get("data", []):
            m = metrics(row)
            m["name"] = row.get("campaign_name", "(tanpa nama)")
            m["on"] = status.get(row.get("campaign_id")) == "ACTIVE"
            # hanya yang aktif / spend / purchase hari ini
            if m["on"] or m["spend"] > 0 or m["order"] > 0:
                out.append(m)
    except Exception:
        pass
    out.sort(key=lambda c: -c["spend"])
    return out


def account_name(aid):
    try:
        return api("/act_%s" % aid, {"fields": "name"}).get("name", "")
    except Exception:
        return ""


def discover():
    ids = []
    try:
        d = api("/me/adaccounts", {"fields": "account_id", "limit": 500})
        for a in d.get("data", []):
            ids.append(a["account_id"])
    except Exception:
        pass
    return ids


SUM_KEYS = ["spend", "impresi", "reach", "klik", "viewlp", "klikwa", "contact", "order", "value"]


def _recompute(m):
    m["frekuensi"] = round(m["impresi"] / m["reach"], 2) if m.get("reach") else 0.0
    m["ctr"] = round(m["klik"] / m["impresi"] * 100, 2) if m.get("impresi") else 0.0
    m["cpc"] = int(round(m["spend"] / m["klik"])) if m.get("klik") else 0
    m["roas"] = round(m["value"] / m["spend"], 2) if m.get("spend") else 0


def merge_by_se(accounts):
    """Gabung akun-akun dgn SE yang sama jadi 1 entri (metrik dijumlahkan)."""
    order = []
    by = {}
    for a in accounts:
        k = a["se"]
        if k not in by:
            by[k] = a
            a["_ids"] = [a["id"]]
            order.append(k)
        else:
            m = by[k]
            m["_ids"].append(a["id"])
            for pk, pv in a["periods"].items():
                dst = m["periods"].setdefault(pk, {})
                for kk in SUM_KEYS:
                    dst[kk] = dst.get(kk, 0) + pv.get(kk, 0)
            m["campaigns"] = (m.get("campaigns") or []) + (a.get("campaigns") or [])
    out = []
    for k in order:
        m = by[k]
        if len(m["_ids"]) > 1:  # hanya SE yang punya >1 akun yang perlu dihitung ulang
            for pk in m["periods"]:
                _recompute(m["periods"][pk])
            (m.get("campaigns") or []).sort(key=lambda c: -(c.get("spend") or 0))
        m["id"] = ",".join(m.pop("_ids"))
        out.append(m)
    return out


def main():
    ids = list(ACC.keys()) or discover()
    if not ids:
        # accounts.json tak terbaca DAN /me/adaccounts gagal. Jangan sentuh apa pun:
        # menimpa data.json di sini akan mengosongkan dashboard dan menghapus cache.
        print("GAGAL: daftar akun iklan kosong. data.json & history.json tidak diubah.",
              file=sys.stderr)
        return 1
    tz = datetime.timezone(datetime.timedelta(hours=7))  # WIB
    now = datetime.datetime.now(tz)
    bulan = bulan_bulan(now)
    ini = bulan[-1]["key"]
    lalu = bulan[-2]["key"] if len(bulan) > 1 else ini
    # Bulan berjalan + bulan lalu selalu ditarik ulang (angka bulan lalu masih bisa
    # bergerak beberapa hari karena attribution window). Bulan sebelumnya dari cache.
    hidup = {ini, lalu}
    hist = load_hist()

    accounts = []
    for aid in ids:
        info = ACC.get(aid, {})
        per = {k: acct_period(aid, v) for k, v in PERIODS.items()}
        hb = hist.setdefault(aid, {})
        for b in bulan:
            k = b["key"]
            ent = hb.get(k)
            # Cache hanya dipakai bila bulannya sudah tutup buku DAN rentang tanggal entri
            # cocok dengan yang diminta sekarang (menjaga dari entri separuh bulan yang beku).
            segar = bool(ent) and ent.get("until") == b["until"]
            if not b["current"] and k not in hidup and segar:
                m = ent["m"]
            else:
                m, ok = acct_range(aid, b["since"], b["until"], dbg=(k == lalu))
                if ok:
                    if not b["current"]:   # bulan berjalan masih separuh -> jangan di-cache
                        hb[k] = {"until": b["until"], "m": m}
                elif segar:
                    m = ent["m"]           # API gagal: pakai nilai cache lama, jangan timpa
            per[k] = dict(m)              # salin: merge_by_se mengubah dict di tempat
        per["bulanan"] = dict(per[ini])   # alias lama, biar dashboard versi lama tetap jalan
        per["bulanlalu"] = dict(per[lalu])
        accounts.append({
            "id": aid,
            "se": info.get("se") or account_name(aid) or aid,
            "de": info.get("de", ""),
            "produk": info.get("produk", ""),
            "periods": per,
            "campaigns": campaigns_today(aid),
        })

    for k in [k for k in hist if k != "_v" and k not in ids]:
        hist.pop(k)                       # buang akun yang sudah tidak dipakai
    try:
        tulis_json(HIST_FILE, hist)
    except Exception as e:
        print("PERINGATAN: history.json gagal ditulis (%s)" % e, file=sys.stderr)

    accounts = merge_by_se(accounts)
    os.makedirs(OUTDIR, exist_ok=True)
    out = {
        "updated": now.strftime("%Y-%m-%d %H:%M"),
        "bulan_ini_label": [b["label"] for b in bulan if b["key"] == ini][0],
        "bulan_lalu_label": [b["label"] for b in bulan if b["key"] == lalu][0],
        "months": bulan,
        "gagal": _gagal[0],   # >0 artinya ada panggilan API gagal -> angka bisa kurang
        "accounts": accounts,
    }
    tulis_json(os.path.join(OUTDIR, "data.json"), out)
    tulis_json(os.path.join(OUTDIR, "_debug_actions.json"), sorted(_seen))
    tulis_json(os.path.join(OUTDIR, "_debug_contact.json"),
               {ACC.get(k, {}).get("se", k): v for k, v in _contact_dbg.items()})
    print("OK:", len(accounts), "SE ·", len(bulan), "bulan (",
          ", ".join(b["label"] for b in bulan), ") ->", os.path.join(OUTDIR, "data.json"))
    if _gagal[0]:
        print("PERINGATAN: %d panggilan insight gagal — sebagian angka bisa kurang."
              % _gagal[0], file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main() or 0)
