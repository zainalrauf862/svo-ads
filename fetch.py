#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SVO Ads — tarik data Meta Ads semua akun -> /var/www/tim/data.json
Dijalankan berkala (cron) di VPS. Token dibaca dari file token.txt (tidak pernah masuk kode).
Stdlib only (tanpa pip).
"""
import json, os, urllib.parse, urllib.request, datetime

BASE = "https://graph.facebook.com/v21.0"
DIR = os.path.dirname(os.path.abspath(__file__))
OUTDIR = "/var/www/tim"

TOKEN = open(os.path.join(DIR, "token.txt")).read().strip()
try:
    ACC = json.load(open(os.path.join(DIR, "accounts.json")))  # {id: {se,de,produk}}
except Exception:
    ACC = {}

PERIODS = {"harian": "today", "mingguan": "last_7d", "bulanan": "last_30d"}
FIELDS = "spend,impressions,reach,frequency,clicks,inline_link_clicks,ctr,cpc,actions,action_values,purchase_roas"

# Pemetaan action_type Meta -> tahap funnel (best-effort; dikalibrasi dari _debug_actions.json)
# Pemetaan event Meta -> funnel, SAMA dengan pull_novia.py (ambil action_type PERTAMA yg cocok)
# Catatan: "Klik WA" = Add to Cart; "Contact" = event custom pixel Novia.
MAP = {
    "viewlp":   ["landing_page_view", "omni_landing_page_view"],
    "klikwa":   ["add_to_cart", "offsite_conversion.fb_pixel_add_to_cart", "onsite_web_add_to_cart"],
    "contact":  ["contact", "contact_total",
                 "offsite_conversion.fb_pixel_contact", "offsite_conversion.fb_pixel_custom"],
    "purchase": ["omni_purchase", "purchase", "offsite_conversion.fb_pixel_purchase"],
}
_seen = set()


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


def metrics(row):
    a = row.get("actions"); av = row.get("action_values")
    spend = fnum(row.get("spend"))
    order = actval(a, MAP["purchase"])
    value = actval(av, MAP["purchase"])
    klik = int(fnum(row.get("inline_link_clicks"))) or actval(a, ["link_click"])
    roas = round(actvalf(row.get("purchase_roas"), MAP["purchase"]), 2)
    if not roas and spend:
        roas = round(value / spend, 2)
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
        "contact": actval(a, MAP["contact"]),
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
        return metrics({})


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


def main():
    ids = list(ACC.keys()) or discover()
    accounts = []
    for aid in ids:
        info = ACC.get(aid, {})
        accounts.append({
            "id": aid,
            "se": info.get("se") or account_name(aid) or aid,
            "de": info.get("de", ""),
            "produk": info.get("produk", ""),
            "periods": {k: acct_period(aid, v) for k, v in PERIODS.items()},
            "campaigns": campaigns_today(aid),
        })
    os.makedirs(OUTDIR, exist_ok=True)
    tz = datetime.timezone(datetime.timedelta(hours=7))  # WIB
    out = {"updated": datetime.datetime.now(tz).strftime("%Y-%m-%d %H:%M"), "accounts": accounts}
    with open(os.path.join(OUTDIR, "data.json"), "w") as f:
        json.dump(out, f, ensure_ascii=False)
    with open(os.path.join(OUTDIR, "_debug_actions.json"), "w") as f:
        json.dump(sorted(_seen), f, ensure_ascii=False, indent=2)
    print("OK:", len(accounts), "akun ->", os.path.join(OUTDIR, "data.json"))


if __name__ == "__main__":
    main()
