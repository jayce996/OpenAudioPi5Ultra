#!/usr/bin/env python3
import os, subprocess, time, threading, queue, yaml
from flask import Flask, request, redirect, url_for, render_template, Response, jsonify

CFG_PATH = "/etc/audioos/audioos.yaml"

app = Flask(__name__)

def load_cfg():
    try:
        with open(CFG_PATH, "r") as f:
            return yaml.safe_load(f) or {}
    except Exception:
        return {}

def save_cfg(cfg):
    with open(CFG_PATH, "w") as f:
        yaml.safe_dump(cfg, f, sort_keys=False)

def sh(cmd):
    return subprocess.run(cmd, shell=isinstance(cmd, str), check=False, capture_output=True, text=True)

@app.get("/")
def index():
    cfg = load_cfg()
    prof = (cfg.get("profiles") or {}).get("current", "hq")
    dev = (cfg.get("device") or {}).get("alsa", "default")
    dop = bool((cfg.get("device") or {}).get("dop", False))
    cards = sh("aplay -l").stdout
    return render_template("index.html", profile=prof, device=dev, dop=dop, cards=cards)

@app.post("/set")
def set_cfg():
    cfg = load_cfg()
    cfg.setdefault("device", {})
    cfg["device"]["alsa"] = request.form.get("device", "default").strip() or "default"
    cfg["device"]["dop"] = True if request.form.get("dop") == "on" else False
    save_cfg(cfg)
    sh("audioos-apply-profile " + ((cfg.get("profiles") or {}).get("current", "hq")))
    return redirect(url_for("index"))

@app.post("/profile/<name>")
def set_profile(name):
    name = name.lower()
    if name not in ("hq", "ll"):
        return "Invalid profile", 400
    cfg = load_cfg()
    cfg.setdefault("profiles", {})["current"] = name
    save_cfg(cfg)
    sh(f"audioos-apply-profile {name}")
    return redirect(url_for("index"))

@app.get("/status")
def status():
    cfg = load_cfg()
    out = {
        "device": (cfg.get("device") or {}).get("alsa", "default"),
        "profile": (cfg.get("profiles") or {}).get("current", "hq"),
        "services": {}
    }
    for svc in ("squeezelite", "librespot", "shairport-sync", "audioos-ui"):
        r = sh(f"systemctl is-active {svc}.service")
        out["services"][svc] = r.stdout.strip() or r.stderr.strip()
    return jsonify(out)

@app.get("/logs/<svc>")
def logs(svc):
    svc = svc.replace(".service","")
    cmd = f"journalctl -u {svc}.service -n 200 --no-pager"
    txt = sh(cmd).stdout
    return Response(txt, mimetype="text/plain")

@app.get("/logs/live/<svc>")
def logs_live(svc):
    svc = svc.replace(".service","")
    def generate():
        p = subprocess.Popen(["journalctl", "-u", f"{svc}.service", "-f", "-n", "0", "-o", "cat"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        try:
            while True:
                line = p.stdout.readline()
                if not line:
                    break
                yield line
        finally:
            p.terminate()
    return Response(generate(), mimetype="text/plain")

@app.post("/latency_test")
def latency_test():
    # Lightweight: report current buffer parameters from squeezelite + kernel scheduling info.
    sq = sh("systemctl show squeezelite.service -p ExecStart").stdout
    uname = sh("uname -a").stdout
    return Response(f"Kernel: {uname}\n{sqr(sq)}", mimetype="text/plain")

def sqr(s):
    return s.replace("\\n", "\n")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8787, debug=False)
