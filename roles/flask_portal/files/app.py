import os, re, shutil, subprocess, mimetypes
from pathlib import Path
from functools import wraps

import pam
from flask import (Flask, render_template_string, request, session,
                   redirect, url_for, send_file, jsonify, flash, abort)
from werkzeug.utils import secure_filename

app = Flask(__name__)
app.config.from_pyfile('config.py')

SECRET_KEY  = app.config['SECRET_KEY']
SAMBA_ROOT  = app.config['SAMBA_ROOT']
ADMIN_USERS = set(app.config['ADMIN_USERS'])
PORTAL_DIR  = os.path.dirname(os.path.abspath(__file__))
BANNER_DIR  = os.path.join(PORTAL_DIR, 'banners')
os.makedirs(BANNER_DIR, exist_ok=True)

# ── helpers ───────────────────────────────────────────────────────────────────
def safe_path(disk: str, rel: str = '') -> Path:
    base = (Path(SAMBA_ROOT) / secure_filename(disk)).resolve()
    if rel:
        parts = [secure_filename(p) for p in Path(rel).parts if p not in ('', '.', '..')]
        target = base.joinpath(*parts).resolve() if parts else base
    else:
        target = base
    if not str(target).startswith(str(base) + os.sep) and target != base:
        abort(403)
    return target

def user_disks() -> list:
    if session.get('user') in ADMIN_USERS:
        try:
            return sorted(d.name for d in Path(SAMBA_ROOT).iterdir() if d.is_dir())
        except Exception:
            return []
    disks = []
    try:
        for d in Path(SAMBA_ROOT).iterdir():
            if d.is_dir() and os.access(str(d), os.R_OK):
                disks.append(d.name)
    except Exception:
        pass
    return sorted(disks)

def login_required(f):
    @wraps(f)
    def wrapper(*a, **kw):
        if not session.get('logged_in'):
            return redirect(url_for('login', next=request.url))
        return f(*a, **kw)
    return wrapper

def admin_required(f):
    @wraps(f)
    def wrapper(*a, **kw):
        if not session.get('logged_in'):
            return redirect(url_for('login'))
        if session.get('user') not in ADMIN_USERS:
            abort(403)
        return f(*a, **kw)
    return wrapper

def fmt_size(n: int) -> str:
    for u in ('B', 'KB', 'MB', 'GB', 'TB'):
        if n < 1024:
            return f'{n:.1f} {u}'
        n /= 1024
    return f'{n:.1f} PB'

def get_banner():
    for ext in ('jpg', 'jpeg', 'png', 'gif', 'webp'):
        p = os.path.join(BANNER_DIR, f'banner.{ext}')
        if os.path.exists(p):
            return url_for('banner_img', filename=f'banner.{ext}')
    return ''

def get_notice():
    f = os.path.join(PORTAL_DIR, 'notice.html')
    return open(f).read().strip() if os.path.exists(f) else ''

def file_icon(ext: str) -> str:
    e = ext.lower().lstrip('.')
    m = {
        'pdf': 'ti-file-type-pdf',
        'doc': 'ti-file-type-doc', 'docx': 'ti-file-type-docx',
        'xls': 'ti-file-spreadsheet', 'xlsx': 'ti-file-spreadsheet',
        'csv': 'ti-file-spreadsheet',
        'ppt': 'ti-presentation', 'pptx': 'ti-presentation',
        'jpg': 'ti-photo', 'jpeg': 'ti-photo', 'png': 'ti-photo',
        'gif': 'ti-photo', 'bmp': 'ti-photo', 'webp': 'ti-photo',
        'mp4': 'ti-video', 'avi': 'ti-video', 'mkv': 'ti-video', 'mov': 'ti-video',
        'mp3': 'ti-music', 'wav': 'ti-music', 'ogg': 'ti-music',
        'zip': 'ti-file-zip', 'rar': 'ti-file-zip', '7z': 'ti-file-zip', 'tar': 'ti-file-zip',
        'txt': 'ti-file-text', 'log': 'ti-file-text',
        'py': 'ti-file-code', 'js': 'ti-file-code', 'sh': 'ti-file-code',
    }
    return m.get(e, 'ti-file')

def get_server_status() -> dict:
    s = {'samba': False, 'raid': 'N/D', 'mem_pct': 0, 'uptime': 'N/D', 'ip': ''}
    try:
        r = subprocess.run(['systemctl', 'is-active', 'smbd'],
                           capture_output=True, text=True, timeout=3)
        s['samba'] = r.stdout.strip() == 'active'
    except Exception:
        pass
    try:
        with open('/proc/meminfo') as f:
            d = {l.split(':')[0]: int(l.split()[1]) for l in f if ':' in l}
        t = d.get('MemTotal', 1)
        s['mem_pct'] = int((t - d.get('MemAvailable', t)) / t * 100)
    except Exception:
        pass
    try:
        with open('/proc/uptime') as f:
            sec = int(float(f.read().split()[0]))
        d2, r2 = divmod(sec, 86400)
        h, _ = divmod(r2, 3600)
        s['uptime'] = f'{d2}d {h}h' if d2 else f'{h}h'
    except Exception:
        pass
    try:
        with open('/proc/mdstat') as f:
            s['raid'] = 'Ativo' if 'active' in f.read() else 'Inativo'
    except Exception:
        pass
    try:
        import socket
        s['ip'] = socket.gethostbyname(socket.gethostname())
    except Exception:
        pass
    return s

# ── templates ─────────────────────────────────────────────────────────────────
CSS = """
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@tabler/icons-webfont@latest/dist/tabler-icons.min.css">
<style>
*{box-sizing:border-box;margin:0;padding:0;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif}
html,body{height:100%;overflow:hidden}
body{background:#f4f6f8;color:#1a2a3a;display:flex;flex-direction:column}
.topbar{background:#1c3557;display:flex;align-items:center;justify-content:space-between;
        padding:0 16px;height:48px;flex-shrink:0}
.tb-left{display:flex;align-items:center;gap:10px}
.logo-box{width:32px;height:32px;border-radius:8px;background:rgba(255,255,255,.15);
          display:flex;align-items:center;justify-content:center;flex-shrink:0}
.logo-box i{color:#fff;font-size:16px}
.tb-title{color:#e8f0f8;font-size:11px;font-weight:500;line-height:1.3}
.tb-sub{color:#7a9ec0;font-size:9px}
.tb-right{display:flex;align-items:center;gap:6px}
.pill{display:flex;align-items:center;gap:5px;background:rgba(255,255,255,.1);
      border:0.5px solid rgba(255,255,255,.2);border-radius:20px;padding:4px 10px;
      color:#c0d8f0;font-size:11px}
.topbtn{display:flex;align-items:center;gap:4px;padding:4px 9px;
        border:0.5px solid rgba(255,255,255,.2);border-radius:6px;
        color:#a0c4e0;font-size:10px;cursor:pointer;background:transparent;
        text-decoration:none;font-family:inherit}
.topbtn:hover{background:rgba(255,255,255,.1);text-decoration:none;color:#fff}
.body{display:flex;flex:1;overflow:hidden}
.sidebar{width:190px;min-width:190px;background:#fff;border-right:0.5px solid #d0d7de;
         display:flex;flex-direction:column;overflow:hidden;flex-shrink:0}
.sidebar-hdr{padding:10px 12px 8px;border-bottom:0.5px solid #e8ecf0;
             display:flex;align-items:center;justify-content:space-between}
.sidebar-hdr span{font-size:9px;font-weight:500;color:#7a8a9a;
                  text-transform:uppercase;letter-spacing:.8px}
.search-wrap{padding:7px 10px;border-bottom:0.5px solid #e8ecf0}
.search-wrap input{width:100%;background:#f4f6f8;border:0.5px solid #d0d7de;
                   border-radius:6px;padding:5px 8px;font-size:11px;color:#1a2a3a;outline:none}
.share-list{flex:1;overflow-y:auto;padding:4px 0}
.si{display:flex;align-items:center;gap:8px;padding:6px 12px;cursor:pointer;
    border-left:2px solid transparent;text-decoration:none;color:inherit}
.si:hover{background:#f4f6f8;text-decoration:none}
.si.active{background:#e8f0fb;border-left-color:#1c5fad}
.si i.ico{font-size:14px;color:#7a8a9a;flex-shrink:0}
.si.active i.ico{color:#1c5fad}
.si .nm{font-size:11px;color:#4a5a6a;flex:1;white-space:nowrap;
        overflow:hidden;text-overflow:ellipsis}
.si.active .nm{color:#1c5fad;font-weight:500}
.center{flex:1;display:flex;flex-direction:column;overflow:hidden;min-width:0}
.banner-wrap{background:#fff;border-bottom:0.5px solid #d0d7de;flex-shrink:0;overflow:hidden}
.banner-img{width:100%;max-height:140px;object-fit:cover;display:block}
.notice-bar{background:#fff;border-bottom:0.5px solid #d0d7de;padding:7px 14px;
            flex-shrink:0;display:flex;align-items:center;gap:10px}
.notice-tag{display:inline-flex;align-items:center;gap:4px;background:#fff8e6;
            color:#8a5a00;font-size:9px;font-weight:500;padding:3px 9px;
            border-radius:20px;text-transform:uppercase;letter-spacing:.4px;
            flex-shrink:0;border:0.5px solid #f0d080}
.notice-txt{font-size:11px;color:#4a5a6a;white-space:nowrap;overflow:hidden;
            text-overflow:ellipsis;flex:1}
.fm{flex:1;padding:10px 14px;display:flex;flex-direction:column;gap:8px;
    overflow:hidden;min-height:0}
.fm-header{display:flex;align-items:center;justify-content:space-between;
           flex-shrink:0;gap:8px}
.fm-title{display:flex;align-items:center;gap:8px;min-width:0}
.fm-title i{font-size:18px;color:#1c5fad;flex-shrink:0}
.fm-title h3{font-size:13px;font-weight:500;color:#1a2a3a;
             white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.fm-path{font-size:10px;color:#9aaab8;font-family:monospace}
.fm-btns{display:flex;gap:5px;flex-shrink:0}
.fmbtn{display:flex;align-items:center;gap:4px;background:#fff;
       border:0.5px solid #c8d4e0;border-radius:5px;padding:4px 9px;
       font-size:11px;color:#4a5a6a;cursor:pointer;white-space:nowrap;
       font-family:inherit;text-decoration:none}
.fmbtn:hover{background:#f4f6f8;text-decoration:none;color:#1a2a3a}
.fmbtn i{font-size:13px}
.fmbtn.prim{background:#1c3557;border-color:#1c3557;color:#fff}
.fmbtn.prim:hover{background:#243f6a;color:#fff}
.fmbtn.red{background:#fef0f0;border-color:#f0b0b0;color:#a03030}
.fm-table{flex:1;background:#fff;border:0.5px solid #d0d7de;border-radius:6px;
          overflow-y:auto;min-height:0}
table{width:100%;border-collapse:collapse;font-size:12px}
thead th{background:#f4f6f8;padding:7px 10px;text-align:left;font-size:10px;font-weight:500;
         color:#7a8a9a;text-transform:uppercase;letter-spacing:.4px;
         border-bottom:0.5px solid #d0d7de;position:sticky;top:0;z-index:1}
tbody td{padding:6px 10px;border-bottom:0.5px solid #eef0f2;color:#1a2a3a;vertical-align:middle}
tbody tr:last-child td{border-bottom:none}
tbody tr:hover td{background:#f8f9fa}
.fi i{font-size:15px;color:#4a8ad4}
.fi.fo i{color:#d4931a}
.fname{cursor:pointer;font-size:12px;color:#1a2a3a;text-decoration:none}
.fname:hover{color:#1c5fad;text-decoration:underline}
.fsz{color:#9aaab8;text-align:right;font-family:monospace;font-size:11px}
.fac{text-align:right;white-space:nowrap}
.fac button,.fac a{display:inline-flex;align-items:center;gap:3px;background:#f0f2f4;
                    border:0.5px solid #d0d7de;border-radius:4px;padding:3px 7px;font-size:10px;
                    color:#5a6a7a;cursor:pointer;margin-left:2px;text-decoration:none;
                    font-family:inherit}
.fac button:hover,.fac a:hover{background:#e4e8ee}
.fac button.g,.fac a.g{background:#e8f5ec;border-color:#9ad0aa;color:#2a6a3a}
.fac button.r{background:#fef0f0;border-color:#f0b0b0;color:#a03030}
.fac i{font-size:11px}
.right-col{width:175px;min-width:175px;background:#fff;border-left:0.5px solid #d0d7de;
           overflow-y:auto;flex-shrink:0;padding:10px}
.card{background:#f4f6f8;border:0.5px solid #d0d7de;border-radius:8px;padding:10px;margin-bottom:10px}
.card-title{font-size:9px;font-weight:500;color:#7a8a9a;text-transform:uppercase;
            letter-spacing:.8px;margin-bottom:8px;display:flex;align-items:center;gap:4px}
.card-title i{font-size:13px}
.card-row{display:flex;justify-content:space-between;align-items:center;margin-bottom:4px;gap:4px}
.card-lbl{font-size:10px;color:#9aaab8;flex-shrink:0}
.card-val{font-size:10px;font-weight:500;color:#1a2a3a;text-align:right}
.dot-on{width:6px;height:6px;border-radius:50%;background:#2a7a3a;display:inline-block;margin-right:3px}
.dot-off{width:6px;height:6px;border-radius:50%;background:#c03030;display:inline-block;margin-right:3px}
.acct-btn{display:flex;align-items:center;gap:5px;background:#fff;
          border:0.5px solid #c8d4e0;border-radius:5px;padding:5px 8px;
          font-size:10px;color:#5a6a7a;cursor:pointer;width:100%;
          margin-bottom:5px;font-family:inherit;text-decoration:none}
.acct-btn:hover{background:#f4f6f8;text-decoration:none;color:#1a2a3a}
.acct-btn i{font-size:13px}
.statusbar{background:#fff;border-top:0.5px solid #d0d7de;padding:0 16px;height:28px;
           display:flex;align-items:center;justify-content:space-between;flex-shrink:0}
.statusbar span{font-size:9px;color:#9aaab8}
.st-on{display:flex;align-items:center;gap:4px;font-size:9px;color:#2a7a3a}
.st-off{display:flex;align-items:center;gap:4px;font-size:9px;color:#c03030}
.flash-wrap{padding:6px 14px;flex-shrink:0}
.flash{padding:6px 10px;border-radius:6px;font-size:11px;margin-bottom:3px;
       display:flex;align-items:center;gap:6px}
.flash-success{background:#e8f5ec;border:0.5px solid #9ad0aa;color:#1a4a2a}
.flash-error{background:#fef0f0;border:0.5px solid #f0b0b0;color:#7a1a1a}
.modal-bg{display:none;position:fixed;inset:0;background:rgba(0,0,0,.35);
          z-index:100;align-items:center;justify-content:center}
.modal-bg.open{display:flex}
.modal{background:#fff;border:0.5px solid #d0d7de;border-radius:10px;
       padding:20px;width:360px;max-width:95vw;box-shadow:0 8px 24px rgba(0,0,0,.1)}
.modal h3{font-size:13px;font-weight:600;color:#1a2a3a;margin-bottom:14px;
          padding-bottom:10px;border-bottom:0.5px solid #e8ecf0}
.modal-footer{display:flex;gap:6px;justify-content:flex-end;margin-top:14px;
              padding-top:10px;border-top:0.5px solid #e8ecf0}
.form-group{margin-bottom:10px}
.form-group label{display:block;font-size:10px;color:#7a8a9a;margin-bottom:4px;font-weight:500}
.form-group input,.form-group select,.form-group textarea{
  background:#f4f6f8;border:0.5px solid #d0d7de;border-radius:6px;
  padding:6px 9px;font-size:12px;color:#1a2a3a;width:100%;font-family:inherit;outline:none}
.form-group input:focus,.form-group textarea:focus{border-color:#1c5fad;background:#fff}
.welcome{display:flex;flex-direction:column;align-items:center;justify-content:center;
         flex:1;color:#9aaab8;gap:8px;text-align:center}
.welcome i{font-size:40px;color:#d0d7de}
.welcome p{font-size:12px}
.login-page{display:flex;align-items:center;justify-content:center;
            min-height:100vh;background:#f4f6f8}
.login-box{background:#fff;border:0.5px solid #d0d7de;border-radius:12px;
           width:340px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,.08)}
.login-hdr{background:#1c3557;padding:24px;text-align:center}
.login-logo{width:52px;height:52px;border-radius:14px;background:rgba(255,255,255,.15);
            display:flex;align-items:center;justify-content:center;margin:0 auto 10px}
.login-logo i{color:#fff;font-size:24px}
.login-hdr h2{color:#fff;font-size:16px;font-weight:600}
.login-hdr p{color:#7a9ec0;font-size:11px;margin-top:3px}
.login-body{padding:20px;display:flex;flex-direction:column;gap:12px}
.error-msg{font-size:11px;color:#a03030;padding:8px 10px;background:#fef0f0;
           border:0.5px solid #f0b0b0;border-radius:6px;display:flex;align-items:center;gap:6px}
.login-btn{background:#1c3557;color:#fff;border:none;border-radius:7px;padding:9px;
           font-size:13px;cursor:pointer;width:100%;font-family:inherit;font-weight:500}
.login-btn:hover{background:#243f6a}
</style>"""

LOGIN_T = """<!DOCTYPE html><html lang="pt-BR">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>CDPNI — Login</title>""" + CSS + """
</head>
<body style="overflow:auto">
<div class="login-page">
  <div class="login-box">
    <div class="login-hdr">
      <div class="login-logo"><i class="ti ti-building-prison"></i></div>
      <h2>CDPNI</h2>
      <p>Portal de Arquivos</p>
    </div>
    <form method="post" class="login-body">
      {% if error %}
      <div class="error-msg"><i class="ti ti-alert-circle"></i>{{ error }}</div>
      {% endif %}
      <div class="form-group">
        <label>Usuário</label>
        <input type="text" name="user" value="{{ req_user }}" autofocus autocomplete="username">
      </div>
      <div class="form-group">
        <label>Senha</label>
        <input type="password" name="password" autocomplete="current-password">
      </div>
      <button type="submit" class="login-btn">Entrar</button>
    </form>
  </div>
</div>
</body></html>"""

BASE = """<!DOCTYPE html><html lang="pt-BR">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>CDPNI — Arquivos</title>""" + CSS + """
</head>
<body>
<div class="topbar">
  <div class="tb-left">
    <div class="logo-box"><i class="ti ti-building-prison"></i></div>
    <div>
      <div class="tb-title">Centro de Detenção Provisória de Nova Independência</div>
      <div class="tb-sub">Portal de Arquivos — CDPNI · {{ srv.ip }}</div>
    </div>
  </div>
  <div class="tb-right">
    <div class="pill"><i class="ti ti-user-circle"></i>{{ session.user }}</div>
    {% if session.user in admin_users %}
    <a href="{{ url_for('admin') }}" class="topbtn"><i class="ti ti-settings"></i>Admin</a>
    {% endif %}
    <a href="{{ url_for('change_pass_page') }}" class="topbtn"><i class="ti ti-lock"></i>Senha</a>
    <a href="{{ url_for('logout') }}" class="topbtn"><i class="ti ti-logout"></i>Sair</a>
  </div>
</div>

<div class="body">
  <div class="sidebar">
    <div class="sidebar-hdr">
      <span>Compartilhamentos</span>
      <i class="ti ti-folders" style="font-size:13px;color:#b0c0d0"></i>
    </div>
    <div class="search-wrap">
      <input type="text" id="shareSearch" placeholder="Filtrar..." oninput="filterShares(this.value)">
    </div>
    <div class="share-list" id="shareList">
      {% for d in all_disks %}
      <a href="{{ url_for('browse', disk=d, rel='') }}" class="si{% if d == active_disk %} active{% endif %}">
        <i class="ti ti-folder ico"></i>
        <span class="nm">{{ d }}</span>
      </a>
      {% else %}
      <div style="padding:12px;font-size:11px;color:#9aaab8">Sem acesso.</div>
      {% endfor %}
    </div>
  </div>

  <div class="center">
    {% if banner %}
    <div class="banner-wrap">
      <img src="{{ banner }}" class="banner-img" alt="">
    </div>
    {% endif %}
    {% if notice %}
    <div class="notice-bar">
      <span class="notice-tag"><i class="ti ti-speakerphone"></i>Aviso</span>
      <span class="notice-txt">{{ notice|safe }}</span>
    </div>
    {% endif %}
    {% with msgs = get_flashed_messages(with_categories=True) %}
    {% if msgs %}
    <div class="flash-wrap">
      {% for cat, msg in msgs %}
      <div class="flash flash-{{ cat }}">
        <i class="ti ti-{{ 'check' if cat == 'success' else 'alert-circle' }}"></i>{{ msg }}
      </div>
      {% endfor %}
    </div>
    {% endif %}
    {% endwith %}
    {% block body %}{% endblock %}
  </div>

  <div class="right-col">
    <div class="card">
      <div class="card-title"><i class="ti ti-server"></i>Servidor</div>
      <div class="card-row">
        <span class="card-lbl">Samba</span>
        <span class="card-val">
          {% if srv.samba %}<span class="dot-on"></span>Online
          {% else %}<span class="dot-off"></span>Offline{% endif %}
        </span>
      </div>
      <div class="card-row"><span class="card-lbl">IP</span><span class="card-val">{{ srv.ip }}</span></div>
      <div class="card-row"><span class="card-lbl">RAID</span><span class="card-val">{{ srv.raid }}</span></div>
      <div class="card-row"><span class="card-lbl">Memória</span><span class="card-val">{{ srv.mem_pct }}%</span></div>
      <div class="card-row"><span class="card-lbl">Uptime</span><span class="card-val">{{ srv.uptime }}</span></div>
    </div>
    <div class="card">
      <div class="card-title"><i class="ti ti-key"></i>Minha conta</div>
      <a href="{{ url_for('change_pass_page') }}" class="acct-btn"><i class="ti ti-lock"></i>Trocar senha</a>
      {% if session.user in admin_users %}
      <a href="{{ url_for('admin') }}" class="acct-btn"><i class="ti ti-settings"></i>Administração</a>
      {% endif %}
    </div>
  </div>
</div>

<div class="statusbar">
  <span>CDPNI — Centro de Detenção Provisória de Nova Independência</span>
  {% if srv.samba %}
  <span class="st-on"><span class="dot-on"></span>Samba ativo — cdpni.local</span>
  {% else %}
  <span class="st-off"><span class="dot-off"></span>Samba inativo</span>
  {% endif %}
  <span>Portal v2.0 · Python Flask</span>
</div>

<script>
function filterShares(v){
  document.querySelectorAll('#shareList .si').forEach(function(el){
    el.style.display=el.querySelector('.nm').textContent.toLowerCase().includes(v.toLowerCase())?'':'none';
  });
}
</script>
</body></html>"""

INDEX_T = BASE + """
{% block body %}
<div class="fm">
  <div class="welcome">
    <i class="ti ti-folders"></i>
    <p>Selecione um compartilhamento na lista à esquerda.</p>
  </div>
</div>
{% endblock %}"""

BROWSE_T = BASE + """
{% block body %}
<div class="fm">
  <div class="fm-header">
    <div class="fm-title">
      <i class="ti ti-folder-open"></i>
      <div>
        <h3>{{ disk }}{% if rel %}/{{ rel }}{% endif %}</h3>
        <span class="fm-path">\\\\{{ srv.ip }}\\{{ disk }}{% if rel %}\\{{ rel.replace('/','\\\\')|e }}{% endif %}</span>
      </div>
    </div>
    <div class="fm-btns">
      {% if rel %}
      <a href="{{ url_for('browse', disk=disk, rel='/'.join(rel.split('/')[:-1])) }}" class="fmbtn">
        <i class="ti ti-arrow-up"></i>Voltar
      </a>
      {% endif %}
      <button class="fmbtn prim" onclick="openUpload()"><i class="ti ti-upload"></i>Enviar</button>
      <button class="fmbtn" onclick="openMkdir()"><i class="ti ti-folder-plus"></i>Nova pasta</button>
    </div>
  </div>

  <div class="fm-table">
    <table>
      <thead><tr>
        <th style="width:26px"></th>
        <th>Nome</th>
        <th style="width:80px;text-align:right">Tamanho</th>
        <th style="width:180px;text-align:right">Ações</th>
      </tr></thead>
      <tbody>
      {% for e in entries %}
      <tr>
        <td>
          <div class="fi{% if e.is_dir %} fo{% endif %}">
            <i class="ti {{ 'ti-folder' if e.is_dir else e.icon }}"></i>
          </div>
        </td>
        <td>
          {% if e.is_dir %}
          <a href="{{ url_for('browse', disk=disk, rel=(rel+'/' if rel else '')+e.name) }}" class="fname">{{ e.name }}</a>
          {% else %}
          <span class="fname">{{ e.name }}</span>
          {% endif %}
        </td>
        <td class="fsz">{{ '' if e.is_dir else e.size }}</td>
        <td class="fac">
          {% if not e.is_dir %}
          <a href="{{ url_for('download', disk=disk, rel=(rel+'/' if rel else '')+e.name) }}" class="g">
            <i class="ti ti-download"></i>Baixar
          </a>
          {% endif %}
          <button onclick="openRename('{{ e.name|e }}')"><i class="ti ti-edit"></i></button>
          <button class="r" onclick="confirmDelete('{{ e.name|e }}','{{ 'dir' if e.is_dir else 'file' }}')">
            <i class="ti ti-trash"></i>
          </button>
        </td>
      </tr>
      {% else %}
      <tr><td colspan="4" style="text-align:center;color:#9aaab8;padding:28px;font-size:12px">
        <i class="ti ti-folder-open" style="font-size:28px;display:block;margin-bottom:6px;color:#d0d7de"></i>
        Pasta vazia
      </td></tr>
      {% endfor %}
      </tbody>
    </table>
  </div>
</div>

<div class="modal-bg" id="mRename"><div class="modal">
  <h3>Renomear</h3>
  <form method="post" action="{{ url_for('rename', disk=disk, rel=rel) }}">
    <input type="hidden" name="old_name" id="oldName">
    <div class="form-group"><label>Novo nome</label><input type="text" name="new_name" id="newName"></div>
    <div class="modal-footer">
      <button type="button" class="fmbtn" onclick="closeModal('mRename')">Cancelar</button>
      <button type="submit" class="fmbtn prim">Renomear</button>
    </div>
  </form>
</div></div>

<div class="modal-bg" id="mMkdir"><div class="modal">
  <h3>Nova Pasta</h3>
  <form method="post" action="{{ url_for('mkdir', disk=disk, rel=rel) }}">
    <div class="form-group"><label>Nome da pasta</label><input type="text" name="name" autofocus></div>
    <div class="modal-footer">
      <button type="button" class="fmbtn" onclick="closeModal('mMkdir')">Cancelar</button>
      <button type="submit" class="fmbtn prim">Criar</button>
    </div>
  </form>
</div></div>

<div class="modal-bg" id="mUpload"><div class="modal">
  <h3>Enviar Arquivos</h3>
  <form method="post" action="{{ url_for('upload', disk=disk, rel=rel) }}" enctype="multipart/form-data">
    <div class="form-group"><label>Selecione os arquivos</label>
      <input type="file" name="files" multiple></div>
    <div class="modal-footer">
      <button type="button" class="fmbtn" onclick="closeModal('mUpload')">Cancelar</button>
      <button type="submit" class="fmbtn prim"><i class="ti ti-upload"></i>Enviar</button>
    </div>
  </form>
</div></div>

<form method="post" id="fDel" action="{{ url_for('delete', disk=disk, rel=rel) }}" style="display:none">
  <input type="hidden" name="name" id="delName">
  <input type="hidden" name="is_dir" id="delIsDir">
</form>

<script>
function openRename(n){document.getElementById('oldName').value=n;document.getElementById('newName').value=n;document.getElementById('mRename').classList.add('open');}
function openMkdir(){document.getElementById('mMkdir').classList.add('open');}
function openUpload(){document.getElementById('mUpload').classList.add('open');}
function closeModal(id){document.getElementById(id).classList.remove('open');}
document.querySelectorAll('.modal-bg').forEach(function(m){m.addEventListener('click',function(e){if(e.target===m)m.classList.remove('open');});});
function confirmDelete(name,type){
  if(!confirm('Excluir "'+name+'"?'))return;
  document.getElementById('delName').value=name;
  document.getElementById('delIsDir').value=type==='dir'?'1':'0';
  document.getElementById('fDel').submit();
}
</script>
{% endblock %}"""

PASS_T = BASE + """
{% block body %}
<div class="fm">
  <div style="max-width:360px;margin:20px auto">
    <div class="card" style="background:#fff;padding:16px">
      <div class="card-title" style="font-size:12px;margin-bottom:14px">
        <i class="ti ti-lock"></i>Alterar Senha
      </div>
      <form method="post" action="{{ url_for('change_pass') }}">
        <div class="form-group"><label>Senha Atual</label><input type="password" name="current_pass"></div>
        <div class="form-group"><label>Nova Senha</label><input type="password" name="new_pass"></div>
        <div class="form-group"><label>Confirmar Nova Senha</label><input type="password" name="confirm_pass"></div>
        <button type="submit" class="fmbtn prim" style="width:100%;justify-content:center">Salvar</button>
      </form>
    </div>
  </div>
</div>
{% endblock %}"""

ADMIN_T = BASE + """
{% block body %}
<div class="fm" style="overflow-y:auto">
  <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px;max-width:680px">
    <div class="card" style="background:#fff;padding:14px">
      <div class="card-title"><i class="ti ti-speakerphone"></i>Aviso do Portal</div>
      <form method="post" action="{{ url_for('admin_notice') }}">
        <div class="form-group">
          <textarea name="notice" rows="4" style="background:#f4f6f8;border:0.5px solid #d0d7de;
            border-radius:6px;padding:7px;font-size:11px;color:#1a2a3a;width:100%;
            font-family:inherit">{{ notice }}</textarea>
        </div>
        <button class="fmbtn prim">Salvar aviso</button>
      </form>
    </div>
    <div class="card" style="background:#fff;padding:14px">
      <div class="card-title"><i class="ti ti-photo"></i>Banner do Portal</div>
      {% if banner %}<img src="{{ banner }}" style="max-height:70px;border-radius:4px;margin-bottom:10px;display:block">{% endif %}
      <form method="post" action="{{ url_for('admin_banner_upload') }}" enctype="multipart/form-data">
        <div class="form-group"><input type="file" name="banner" accept="image/*"></div>
        <button class="fmbtn prim">Enviar imagem</button>
        {% if banner %}
        <a href="{{ url_for('admin_banner_delete') }}" class="fmbtn red" style="margin-left:5px">Remover</a>
        {% endif %}
      </form>
    </div>
    <div class="card" style="background:#fff;padding:14px">
      <div class="card-title"><i class="ti ti-key"></i>Resetar Senha de Usuário</div>
      <div class="form-group"><label>Usuário</label><input type="text" id="rpUser"></div>
      <div class="form-group"><label>Nova Senha</label><input type="password" id="rpPass"></div>
      <div class="form-group"><label>Confirmar</label><input type="password" id="rpConf"></div>
      <button class="fmbtn prim" onclick="doResetPass()">Resetar</button>
      <span id="rpMsg" style="font-size:10px;margin-left:6px"></span>
    </div>
  </div>
</div>
<script>
async function doResetPass(){
  var user=document.getElementById('rpUser').value;
  var pass=document.getElementById('rpPass').value;
  var conf=document.getElementById('rpConf').value;
  var msg=document.getElementById('rpMsg');
  if(!user||!pass){msg.textContent='Preencha todos os campos';msg.style.color='#a03030';return;}
  if(pass!==conf){msg.textContent='Senhas nao coincidem';msg.style.color='#a03030';return;}
  var fd=new FormData();fd.append('username',user);fd.append('new_pass',pass);fd.append('confirm_pass',conf);
  var r=await fetch('/admin/user-pass/'+encodeURIComponent(user),{method:'POST',body:fd});
  var j=await r.json();
  msg.textContent=j.message||j.error||'';
  msg.style.color=j.ok?'#2a7a3a':'#a03030';
}
</script>
{% endblock %}"""

# ── contexto base ─────────────────────────────────────────────────────────────
def base_ctx(active_disk=''):
    return {
        'session':     session,
        'admin_users': ADMIN_USERS,
        'banner':      get_banner(),
        'notice':      get_notice(),
        'all_disks':   user_disks(),
        'active_disk': active_disk,
        'srv':         get_server_status(),
    }

# ── rotas ─────────────────────────────────────────────────────────────────────
@app.route('/login', methods=['GET', 'POST'])
def login():
    if session.get('logged_in'):
        return redirect(url_for('index'))
    error = ''
    req_user = ''
    if request.method == 'POST':
        user     = request.form.get('user', '').strip()
        password = request.form.get('password', '')
        req_user = user
        p = pam.pam()
        if p.authenticate(user, password):
            import grp as grp_mod
            groups = []
            try:
                for g in grp_mod.getgrall():
                    if user in g.gr_mem:
                        groups.append(g.gr_name)
            except Exception:
                pass
            session.clear()
            session['logged_in'] = True
            session['user']      = user
            session['groups']    = groups
            session.permanent    = True
            nxt = request.args.get('next')
            return redirect(nxt if nxt and nxt.startswith('/') else url_for('index'))
        error = 'Usuário ou senha inválidos'
    return render_template_string(LOGIN_T, error=error, req_user=req_user)

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

@app.route('/')
@login_required
def index():
    return render_template_string(INDEX_T, **base_ctx())

@app.route('/browse/<disk>/', defaults={'rel': ''})
@app.route('/browse/<disk>/<path:rel>')
@login_required
def browse(disk, rel):
    path = safe_path(disk, rel)
    if not path.is_dir():
        abort(404)
    if not os.access(str(path), os.R_OK):
        abort(403)
    entries = []
    try:
        for item in sorted(path.iterdir(), key=lambda x: (not x.is_dir(), x.name.lower())):
            try:
                stat = item.stat()
                entries.append(type('E', (), {
                    'name':   item.name,
                    'is_dir': item.is_dir(),
                    'size':   fmt_size(stat.st_size),
                    'ext':    item.suffix.upper().lstrip('.') or 'Arquivo',
                    'icon':   file_icon(item.suffix),
                })())
            except PermissionError:
                pass
    except PermissionError:
        abort(403)
    ctx = base_ctx(active_disk=disk)
    ctx.update(disk=disk, rel=rel, entries=entries)
    return render_template_string(BROWSE_T, **ctx)

@app.route('/download/<disk>/<path:rel>')
@login_required
def download(disk, rel):
    path = safe_path(disk, rel)
    if not path.is_file():
        abort(404)
    if not os.access(str(path), os.R_OK):
        abort(403)
    mime, _ = mimetypes.guess_type(str(path))
    return send_file(str(path), mimetype=mime or 'application/octet-stream',
                     as_attachment=True, download_name=path.name)

@app.route('/upload/<disk>/', defaults={'rel': ''}, methods=['POST'])
@app.route('/upload/<disk>/<path:rel>', methods=['POST'])
@login_required
def upload(disk, rel):
    dest = safe_path(disk, rel)
    if not dest.is_dir():
        abort(404)
    if not os.access(str(dest), os.W_OK):
        flash('Sem permissão de escrita', 'error')
        return redirect(url_for('browse', disk=disk, rel=rel))
    files = request.files.getlist('files')
    saved = 0
    for f in files:
        name = secure_filename(f.filename)
        if name:
            f.save(str(dest / name))
            saved += 1
    flash(f'{saved} arquivo(s) enviado(s)', 'success')
    return redirect(url_for('browse', disk=disk, rel=rel))

@app.route('/mkdir/<disk>/', defaults={'rel': ''}, methods=['POST'])
@app.route('/mkdir/<disk>/<path:rel>', methods=['POST'])
@login_required
def mkdir(disk, rel):
    parent = safe_path(disk, rel)
    name   = secure_filename(request.form.get('name', ''))
    if not name:
        flash('Nome inválido', 'error')
        return redirect(url_for('browse', disk=disk, rel=rel))
    target = parent / name
    if target.exists():
        flash('Já existe', 'error')
    else:
        target.mkdir(parents=False, exist_ok=False)
        os.chmod(str(target), 0o777)
        flash(f'Pasta "{name}" criada', 'success')
    return redirect(url_for('browse', disk=disk, rel=rel))

@app.route('/rename/<disk>/', defaults={'rel': ''}, methods=['POST'])
@app.route('/rename/<disk>/<path:rel>', methods=['POST'])
@login_required
def rename(disk, rel):
    parent   = safe_path(disk, rel)
    old_name = secure_filename(request.form.get('old_name', ''))
    new_name = secure_filename(request.form.get('new_name', ''))
    if not old_name or not new_name or old_name == new_name:
        flash('Nome inválido', 'error')
        return redirect(url_for('browse', disk=disk, rel=rel))
    src = parent / old_name
    dst = parent / new_name
    if not src.exists():
        flash('Arquivo não encontrado', 'error')
    elif dst.exists():
        flash('Nome já existe', 'error')
    else:
        src.rename(dst)
        flash('Renomeado', 'success')
    return redirect(url_for('browse', disk=disk, rel=rel))

@app.route('/delete/<disk>/', defaults={'rel': ''}, methods=['POST'])
@app.route('/delete/<disk>/<path:rel>', methods=['POST'])
@login_required
def delete(disk, rel):
    parent = safe_path(disk, rel)
    name   = secure_filename(request.form.get('name', ''))
    is_dir = request.form.get('is_dir') == '1'
    if not name:
        flash('Nome inválido', 'error')
        return redirect(url_for('browse', disk=disk, rel=rel))
    target = parent / name
    if not target.exists():
        flash('Não encontrado', 'error')
    elif is_dir:
        shutil.rmtree(str(target))
        flash(f'Pasta "{name}" removida', 'success')
    else:
        target.unlink()
        flash(f'"{name}" removido', 'success')
    return redirect(url_for('browse', disk=disk, rel=rel))

@app.route('/change-pass', methods=['GET'])
@login_required
def change_pass_page():
    return render_template_string(PASS_T, **base_ctx())

@app.route('/change-pass', methods=['POST'])
@login_required
def change_pass():
    user         = session['user']
    current_pass = request.form.get('current_pass', '')
    new_pass     = request.form.get('new_pass', '')
    confirm      = request.form.get('confirm_pass', '')
    p = pam.pam()
    if not p.authenticate(user, current_pass):
        flash('Senha atual incorreta', 'error')
        return redirect(url_for('change_pass_page'))
    if len(new_pass) < 8:
        flash('Mínimo 8 caracteres', 'error')
        return redirect(url_for('change_pass_page'))
    if new_pass != confirm:
        flash('Senhas não coincidem', 'error')
        return redirect(url_for('change_pass_page'))
    proc = subprocess.run(['sudo', 'chpasswd'],
                          input=f'{user}:{new_pass}',
                          capture_output=True, text=True)
    if proc.returncode != 0:
        flash('Erro ao alterar senha', 'error')
    else:
        subprocess.run(['sudo', 'smbpasswd', '-s', user],
                       input=f'{new_pass}\n{new_pass}\n',
                       capture_output=True, text=True)
        flash('Senha alterada com sucesso', 'success')
    return redirect(url_for('change_pass_page'))

@app.route('/banner-img/<filename>')
def banner_img(filename):
    name = secure_filename(filename)
    path = os.path.join(BANNER_DIR, name)
    if not os.path.exists(path):
        abort(404)
    mime, _ = mimetypes.guess_type(path)
    return send_file(path, mimetype=mime or 'image/jpeg')

@app.route('/admin')
@admin_required
def admin():
    ctx = base_ctx()
    ctx['notice'] = get_notice()
    return render_template_string(ADMIN_T, **ctx)

@app.route('/admin/notice', methods=['POST'])
@admin_required
def admin_notice():
    notice = request.form.get('notice', '')
    notice = re.sub(r'<(?!/?(?:b|i|strong|em|br|p|ul|li|span|a)[\s>])[^>]+>', '', notice)
    with open(os.path.join(PORTAL_DIR, 'notice.html'), 'w') as f:
        f.write(notice)
    flash('Aviso atualizado', 'success')
    return redirect(url_for('admin'))

@app.route('/admin/banner/upload', methods=['POST'])
@admin_required
def admin_banner_upload():
    f = request.files.get('banner')
    if not f or not f.filename:
        flash('Nenhum arquivo', 'error')
        return redirect(url_for('admin'))
    ext = Path(secure_filename(f.filename)).suffix.lower()
    if ext not in ('.jpg', '.jpeg', '.png', '.gif', '.webp'):
        flash('Formato inválido (jpg/png/gif/webp)', 'error')
        return redirect(url_for('admin'))
    for old in Path(BANNER_DIR).glob('banner.*'):
        old.unlink()
    f.save(os.path.join(BANNER_DIR, f'banner{ext}'))
    flash('Banner atualizado', 'success')
    return redirect(url_for('admin'))

@app.route('/admin/banner/delete')
@admin_required
def admin_banner_delete():
    for old in Path(BANNER_DIR).glob('banner.*'):
        old.unlink()
    flash('Banner removido', 'success')
    return redirect(url_for('admin'))

@app.route('/admin/user-pass/<username>', methods=['POST'])
@admin_required
def admin_user_pass(username):
    username = request.form.get('username', username).strip()
    new_pass = request.form.get('new_pass', '')
    confirm  = request.form.get('confirm_pass', '')
    if not username or not re.match(r'^[a-z][a-z0-9_-]{0,31}$', username):
        return jsonify({'ok': False, 'error': 'Usuário inválido'})
    if len(new_pass) < 8:
        return jsonify({'ok': False, 'error': 'Mínimo 8 caracteres'})
    if new_pass != confirm:
        return jsonify({'ok': False, 'error': 'Senhas não coincidem'})
    proc = subprocess.run(['sudo', 'chpasswd'],
                          input=f'{username}:{new_pass}',
                          capture_output=True, text=True)
    if proc.returncode != 0:
        return jsonify({'ok': False, 'error': f'chpasswd: {proc.stderr.strip()}'})
    subprocess.run(['sudo', 'smbpasswd', '-s', username],
                   input=f'{new_pass}\n{new_pass}\n',
                   capture_output=True, text=True)
    return jsonify({'ok': True, 'message': f'Senha de {username} atualizada'})

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000, debug=False)
