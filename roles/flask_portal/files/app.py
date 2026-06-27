import os, re, shutil, subprocess, mimetypes, hashlib
from pathlib import Path
from functools import wraps

import pam
from flask import (Flask, render_template_string, request, session,
                   redirect, url_for, send_file, jsonify, flash, abort)
from werkzeug.utils import secure_filename

app = Flask(__name__)
app.config.from_pyfile('config.py')

SECRET_KEY   = app.config['SECRET_KEY']
SAMBA_ROOT   = app.config['SAMBA_ROOT']
ADMIN_USERS  = set(app.config['ADMIN_USERS'])
PORTAL_DIR   = os.path.dirname(os.path.abspath(__file__))
BANNER_DIR   = os.path.join(PORTAL_DIR, 'banners')
os.makedirs(BANNER_DIR, exist_ok=True)

# ── helpers ──────────────────────────────────────────────────────────────────
def safe_path(disk: str, rel: str = '') -> Path:
    """Resolve e valida caminho dentro do share — evita path traversal."""
    base = (Path(SAMBA_ROOT) / secure_filename(disk)).resolve()
    if rel:
        # Sanitiza cada componente do caminho relativo individualmente
        parts = [secure_filename(p) for p in Path(rel).parts if p not in ('', '.', '..')]
        target = base.joinpath(*parts).resolve() if parts else base
    else:
        target = base
    # Verifica que target está dentro de base (com separador para evitar prefix clash)
    if not str(target).startswith(str(base) + os.sep) and target != base:
        abort(403)
    return target

def user_disks() -> list[str]:
    user   = session.get('user', '')
    groups = session.get('groups', [])
    disks  = []
    if user in ADMIN_USERS:
        try:
            return sorted(
                d.name for d in Path(SAMBA_ROOT).iterdir() if d.is_dir()
            )
        except Exception:
            return []
    for d in Path(SAMBA_ROOT).iterdir():
        if not d.is_dir():
            continue
        if os.access(str(d), os.R_OK):
            disks.append(d.name)
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

def get_banner() -> str:
    for ext in ('jpg', 'jpeg', 'png', 'gif', 'webp'):
        p = os.path.join(BANNER_DIR, f'banner.{ext}')
        if os.path.exists(p):
            return url_for('banner_img', filename=f'banner.{ext}')
    return ''

# ── templates ─────────────────────────────────────────────────────────────────
BASE = r"""
<!DOCTYPE html><html lang="pt-BR">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>CDPNI — Arquivos</title>
<style>
:root{--bg:#0d1b2e;--bg2:#112240;--bg3:#163052;--border:#1e4070;--text:#d4e8f8;
      --muted:#5a8ab4;--accent:#3a8fff;--danger:#ff5a5a;--success:#3fd87a;
      --font:-apple-system,BlinkMacSystemFont,'Segoe UI',system-ui,sans-serif;
      --mono:'Consolas','Courier New',monospace}
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:var(--font);background:var(--bg);color:var(--text);min-height:100vh}
a{color:var(--accent);text-decoration:none}a:hover{text-decoration:underline}
.topbar{background:var(--bg2);border-bottom:1px solid var(--border);padding:.6rem 1.5rem;
        display:flex;align-items:center;gap:1rem}
.topbar-logo{font-weight:700;font-size:1.1rem;color:var(--text)}
.topbar-logo small{color:var(--muted);font-weight:400;font-size:.75rem;margin-left:.4rem}
.topbar-right{margin-left:auto;display:flex;align-items:center;gap:.75rem;font-size:.85rem;color:var(--muted)}
.banner{max-height:200px;width:100%;object-fit:cover;display:block}
.content{max-width:1200px;margin:1.5rem auto;padding:0 1.5rem}
.breadcrumb{font-size:.8rem;color:var(--muted);margin-bottom:1rem}
.breadcrumb a{color:var(--muted)}
.card{background:var(--bg2);border:1px solid var(--border);border-radius:8px;overflow:hidden;margin-bottom:1rem}
.card-header{padding:.6rem 1rem;border-bottom:1px solid var(--border);background:var(--bg3);
             display:flex;align-items:center;gap:.5rem}
.card-header h3{font-size:.9rem;font-weight:600;flex:1}
table{width:100%;border-collapse:collapse;font-size:.85rem}
th{padding:.5rem 1rem;text-align:left;font-size:.72rem;font-weight:600;text-transform:uppercase;
   letter-spacing:.05em;color:var(--muted);background:var(--bg3);border-bottom:1px solid var(--border)}
td{padding:.6rem 1rem;border-bottom:1px solid var(--border);vertical-align:middle}
tr:last-child td{border-bottom:none}tr:hover td{background:rgba(255,255,255,.02)}
.icon{margin-right:.35rem}
.btn{padding:.35rem .8rem;border-radius:6px;border:1px solid var(--border);background:var(--bg3);
     color:var(--text);cursor:pointer;font-size:.78rem;font-family:var(--font);display:inline-flex;
     align-items:center;gap:.3rem;text-decoration:none}
.btn:hover{background:var(--bg2);text-decoration:none}
.btn-primary{background:#1a5fbf;border-color:#2470d0;color:#fff}
.btn-primary:hover{background:#2470d0}
.btn-danger{border-color:var(--danger);color:var(--danger)}
.btn-sm{padding:.2rem .5rem;font-size:.75rem}
.actions{display:flex;gap:.4rem;flex-wrap:wrap;margin-bottom:1rem}
.disks-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:.75rem}
.disk-card{background:var(--bg2);border:1px solid var(--border);border-radius:8px;padding:1rem;
           cursor:pointer;transition:border-color .15s}
.disk-card:hover{border-color:var(--accent)}
.disk-card .di{font-size:2rem;margin-bottom:.4rem}
.disk-card h4{font-size:.9rem;font-weight:600;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.disk-card small{color:var(--muted);font-size:.75rem}
.flash{padding:.6rem 1rem;border-radius:6px;margin-bottom:1rem;font-size:.85rem}
.flash-success{background:#0a2518;border:1px solid #1a4a30;color:var(--success)}
.flash-error{background:#2a0f0f;border:1px solid #4a1f1f;color:var(--danger)}
input[type=text],input[type=password],input[type=file],select{
  background:var(--bg);border:1px solid var(--border);border-radius:6px;
  padding:.4rem .75rem;font-size:.85rem;color:var(--text);width:100%;
  font-family:var(--font);outline:none}
input:focus,select:focus{border-color:var(--accent)}
.form-group{margin-bottom:.8rem}
.form-group label{display:block;font-size:.8rem;color:var(--muted);margin-bottom:.3rem}
.modal-bg{display:none;position:fixed;inset:0;background:rgba(0,0,0,.6);
          backdrop-filter:blur(4px);z-index:100;align-items:center;justify-content:center}
.modal-bg.open{display:flex}
.modal{background:var(--bg2);border:1px solid var(--border);border-radius:10px;
       padding:1.25rem;width:420px;max-width:95vw}
.modal h3{font-size:.95rem;margin-bottom:1rem;padding-bottom:.6rem;border-bottom:1px solid var(--border)}
.modal-footer{display:flex;gap:.5rem;justify-content:flex-end;margin-top:1rem;
              padding-top:.6rem;border-top:1px solid var(--border)}
.login-wrap{display:flex;align-items:center;justify-content:center;min-height:100vh}
.login-box{background:var(--bg2);border:1px solid var(--border);border-radius:12px;width:320px;overflow:hidden}
.login-header{background:var(--bg3);border-bottom:1px solid var(--border);padding:1.25rem;text-align:center}
.login-header .logo{width:48px;height:48px;background:linear-gradient(135deg,#1a5fbf,#3a8fff);
                    border-radius:12px;display:grid;place-items:center;font-size:22px;
                    margin:0 auto .5rem}
.login-body{padding:1.25rem;display:flex;flex-direction:column;gap:.75rem}
.error-msg{font-size:.8rem;color:var(--danger);padding:.5rem .75rem;background:#2a0f0f;
           border:1px solid #4a1f1f;border-radius:6px}
</style>
</head>
<body>
{% if session.logged_in %}
<div class="topbar">
  <div class="topbar-logo">📁 CDPNI <small>Arquivos</small></div>
  <div class="topbar-right">
    <span>{{ session.user }}</span>
    <a href="{{ url_for('logout') }}" class="btn btn-sm">Sair</a>
    {% if session.user in admin_users %}<a href="{{ url_for('admin') }}" class="btn btn-sm">⚙ Admin</a>{% endif %}
  </div>
</div>
{% if banner %}<img src="{{ banner }}" class="banner" alt="">{% endif %}
{% endif %}
{% with msgs = get_flashed_messages(with_categories=True) %}
  {% for cat, msg in msgs %}
  <div class="content"><div class="flash flash-{{ cat }}">{{ msg }}</div></div>
  {% endfor %}
{% endwith %}
{% block body %}{% endblock %}
</body></html>
"""

LOGIN_T = BASE + """
{% block body %}
<div class="login-wrap"><div class="login-box">
  <div class="login-header"><div class="logo">📁</div><h2>CDPNI</h2><p style="color:var(--muted);font-size:.8rem">Portal de Arquivos</p></div>
  <form method="post" class="login-body">
    {% if error %}<div class="error-msg">{{ error }}</div>{% endif %}
    <div class="form-group"><label>Usuário</label><input type="text" name="user" value="{{ req_user }}" autofocus></div>
    <div class="form-group"><label>Senha</label><input type="password" name="password"></div>
    <button type="submit" class="btn btn-primary" style="width:100%;justify-content:center">Entrar</button>
  </form>
</div></div>
{% endblock %}"""

INDEX_T = BASE + """
{% block body %}
<div class="content">
  <p style="color:var(--muted);font-size:.8rem;margin-bottom:1rem">Selecione um compartilhamento:</p>
  <div class="disks-grid">
  {% for disk in disks %}
    <a href="{{ url_for('browse', disk=disk, rel='') }}" style="text-decoration:none">
      <div class="disk-card"><div class="di">🗂️</div>
        <h4>{{ disk }}</h4>
        <small>Compartilhamento Samba</small>
      </div>
    </a>
  {% else %}
    <p style="color:var(--muted)">Nenhum compartilhamento disponível para seu usuário.</p>
  {% endfor %}
  </div>
</div>
{% endblock %}"""

BROWSE_T = BASE + """
{% block body %}
<div class="content">
  <div class="breadcrumb">
    <a href="{{ url_for('index') }}">Início</a> /
    <a href="{{ url_for('browse', disk=disk, rel='') }}">{{ disk }}</a>
    {% set parts = rel.split('/') if rel else [] %}
    {% set accumulated = namespace(path='') %}
    {% for part in parts if part %}
      {% set accumulated.path = accumulated.path + '/' + part %}
      / <a href="{{ url_for('browse', disk=disk, rel=accumulated.path.lstrip('/')) }}">{{ part }}</a>
    {% endfor %}
  </div>
  <div class="actions">
    {% if rel %}
    <a href="{{ url_for('browse', disk=disk, rel='/'.join(rel.split('/')[:-1])) }}" class="btn">⬆ Voltar</a>
    {% endif %}
    <button class="btn btn-primary" onclick="openMkdir()">📁 Nova Pasta</button>
    <button class="btn btn-primary" onclick="openUpload()">⬆ Upload</button>
  </div>
  <div class="card">
    <div class="card-header"><h3>{{ disk }}{% if rel %}/{{ rel }}{% endif %}</h3>
    <span style="color:var(--muted);font-size:.8rem">{{ entries|length }} itens</span></div>
    <table>
      <thead><tr><th>Nome</th><th>Tipo</th><th>Tamanho</th><th style="text-align:right">Ações</th></tr></thead>
      <tbody>
      {% for e in entries %}
      <tr>
        <td>
          {% if e.is_dir %}
          <a href="{{ url_for('browse', disk=disk, rel=(rel+'/' if rel else '')+e.name) }}">
            <span class="icon">📁</span>{{ e.name }}
          </a>
          {% else %}
          <span class="icon">📄</span>{{ e.name }}
          {% endif %}
        </td>
        <td style="color:var(--muted)">{{ 'Pasta' if e.is_dir else e.ext }}</td>
        <td style="color:var(--muted);font-family:var(--mono);font-size:.8rem">{{ '' if e.is_dir else e.size }}</td>
        <td style="text-align:right;white-space:nowrap">
          {% if not e.is_dir %}
          <a href="{{ url_for('download', disk=disk, rel=(rel+'/' if rel else '')+e.name) }}" class="btn btn-sm">⬇ Baixar</a>
          {% endif %}
          <button class="btn btn-sm" onclick="openRename('{{ e.name|e }}')">✏ Renomear</button>
          <button class="btn btn-sm btn-danger" onclick="confirmDelete('{{ e.name|e }}','{{ 'dir' if e.is_dir else 'file' }}')">🗑</button>
        </td>
      </tr>
      {% else %}
      <tr><td colspan="4" style="text-align:center;color:var(--muted);padding:2rem">Pasta vazia</td></tr>
      {% endfor %}
      </tbody>
    </table>
  </div>
</div>

<!-- Modal Renomear -->
<div class="modal-bg" id="mRename"><div class="modal">
  <h3>Renomear</h3>
  <form method="post" action="{{ url_for('rename', disk=disk, rel=rel) }}">
    <input type="hidden" name="old_name" id="oldName">
    <div class="form-group"><label>Novo nome</label><input type="text" name="new_name" id="newName"></div>
    <div class="modal-footer">
      <button type="button" class="btn" onclick="closeModal('mRename')">Cancelar</button>
      <button type="submit" class="btn btn-primary">Renomear</button>
    </div>
  </form>
</div></div>

<!-- Modal Nova Pasta -->
<div class="modal-bg" id="mMkdir"><div class="modal">
  <h3>Nova Pasta</h3>
  <form method="post" action="{{ url_for('mkdir', disk=disk, rel=rel) }}">
    <div class="form-group"><label>Nome da pasta</label><input type="text" name="name" autofocus></div>
    <div class="modal-footer">
      <button type="button" class="btn" onclick="closeModal('mMkdir')">Cancelar</button>
      <button type="submit" class="btn btn-primary">Criar</button>
    </div>
  </form>
</div></div>

<!-- Modal Upload -->
<div class="modal-bg" id="mUpload"><div class="modal">
  <h3>Upload de Arquivos</h3>
  <form method="post" action="{{ url_for('upload', disk=disk, rel=rel) }}" enctype="multipart/form-data">
    <div class="form-group"><label>Selecione os arquivos</label>
      <input type="file" name="files" multiple></div>
    <div class="modal-footer">
      <button type="button" class="btn" onclick="closeModal('mUpload')">Cancelar</button>
      <button type="submit" class="btn btn-primary">⬆ Enviar</button>
    </div>
  </form>
</div></div>

<!-- Form Deletar (oculto) -->
<form method="post" id="fDel" action="{{ url_for('delete', disk=disk, rel=rel) }}" style="display:none">
  <input type="hidden" name="name" id="delName">
  <input type="hidden" name="is_dir" id="delIsDir">
</form>

<script>
function openRename(n){document.getElementById('oldName').value=n;document.getElementById('newName').value=n;document.getElementById('mRename').classList.add('open');}
function openMkdir(){document.getElementById('mMkdir').classList.add('open');}
function openUpload(){document.getElementById('mUpload').classList.add('open');}
function closeModal(id){document.getElementById(id).classList.remove('open');}
document.querySelectorAll('.modal-bg').forEach(m=>m.addEventListener('click',e=>{if(e.target===m)m.classList.remove('open');}));
function confirmDelete(name,type){
  if(!confirm('Excluir "'+name+'"? Esta ação não pode ser desfeita.'))return;
  document.getElementById('delName').value=name;
  document.getElementById('delIsDir').value=type==='dir'?'1':'0';
  document.getElementById('fDel').submit();
}
</script>
{% endblock %}"""

ADMIN_T = BASE + """
{% block body %}
<div class="content">
  <h2 style="margin-bottom:1.5rem">⚙ Administração</h2>
  <div style="display:grid;grid-template-columns:1fr 1fr;gap:1rem">
    <!-- Aviso do portal -->
    <div class="card"><div class="card-header"><h3>Aviso / Notícia</h3></div>
      <div style="padding:1rem">
        <form method="post" action="{{ url_for('admin_notice') }}">
          <div class="form-group"><label>Texto (HTML simples aceito)</label>
            <textarea name="notice" rows="4" style="background:var(--bg);border:1px solid var(--border);border-radius:6px;padding:.5rem;font-size:.85rem;color:var(--text);width:100%;font-family:var(--font)">{{ notice }}</textarea></div>
          <button class="btn btn-primary btn-sm">Salvar</button>
        </form>
      </div>
    </div>
    <!-- Banner -->
    <div class="card"><div class="card-header"><h3>Banner do Portal</h3></div>
      <div style="padding:1rem">
        {% if banner %}<img src="{{ banner }}" style="max-height:80px;border-radius:4px;margin-bottom:.75rem;display:block">{% endif %}
        <form method="post" action="{{ url_for('admin_banner_upload') }}" enctype="multipart/form-data">
          <div class="form-group"><label>Imagem (JPG/PNG/GIF/WebP)</label>
            <input type="file" name="banner" accept="image/*"></div>
          <button class="btn btn-primary btn-sm">Enviar</button>
          {% if banner %}<a href="{{ url_for('admin_banner_delete') }}" class="btn btn-danger btn-sm" style="margin-left:.5rem">Remover</a>{% endif %}
        </form>
      </div>
    </div>
    <!-- Resetar senha de usuário -->
    <div class="card"><div class="card-header"><h3>Resetar Senha de Usuário</h3></div>
      <div style="padding:1rem">
        <form method="post" action="{{ url_for('admin_user_pass', username='') }}" id="fResetPass">
          <div class="form-group"><label>Usuário</label><input type="text" name="username" id="rpUser"></div>
          <div class="form-group"><label>Nova Senha</label><input type="password" name="new_pass" id="rpPass"></div>
          <div class="form-group"><label>Confirmar</label><input type="password" name="confirm_pass" id="rpConf"></div>
          <button type="button" class="btn btn-primary btn-sm" onclick="doResetPass()">Resetar</button>
          <span id="rpMsg" style="font-size:.8rem;margin-left:.5rem"></span>
        </form>
      </div>
    </div>
    <!-- Alterar própria senha -->
    <div class="card"><div class="card-header"><h3>Minha Senha</h3></div>
      <div style="padding:1rem">
        <form method="post" action="{{ url_for('change_pass') }}">
          <div class="form-group"><label>Senha Atual</label><input type="password" name="current_pass"></div>
          <div class="form-group"><label>Nova Senha</label><input type="password" name="new_pass"></div>
          <div class="form-group"><label>Confirmar</label><input type="password" name="confirm_pass"></div>
          <button class="btn btn-primary btn-sm">Salvar</button>
        </form>
      </div>
    </div>
  </div>
</div>
<script>
async function doResetPass(){
  const user=document.getElementById('rpUser').value;
  const pass=document.getElementById('rpPass').value;
  const conf=document.getElementById('rpConf').value;
  if(!user||!pass){document.getElementById('rpMsg').textContent='Preencha todos os campos';return;}
  if(pass!==conf){document.getElementById('rpMsg').textContent='Senhas não coincidem';return;}
  const fd=new FormData();fd.append('username',user);fd.append('new_pass',pass);fd.append('confirm_pass',conf);
  const r=await fetch('/admin/user-pass/'+encodeURIComponent(user),{method:'POST',body:fd});
  const j=await r.json();
  document.getElementById('rpMsg').textContent=j.message||j.error||'';
  document.getElementById('rpMsg').style.color=j.ok?'var(--success)':'var(--danger)';
}
</script>
{% endblock %}"""

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
    return render_template_string(
        LOGIN_T, error=error, req_user=req_user,
        session=session, admin_users=ADMIN_USERS, banner=get_banner()
    )

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

@app.route('/')
@login_required
def index():
    disks = user_disks()
    notice_file = os.path.join(PORTAL_DIR, 'notice.html')
    notice = open(notice_file).read() if os.path.exists(notice_file) else ''
    return render_template_string(
        INDEX_T, disks=disks, notice=notice,
        session=session, admin_users=ADMIN_USERS, banner=get_banner()
    )

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
                    'ext':    item.suffix.upper().lstrip('.') or 'Arquivo'
                })())
            except PermissionError:
                pass
    except PermissionError:
        abort(403)
    return render_template_string(
        BROWSE_T, disk=disk, rel=rel, entries=entries,
        session=session, admin_users=ADMIN_USERS, banner=get_banner()
    )

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
        return redirect(url_for('admin'))
    if len(new_pass) < 8:
        flash('Mínimo 8 caracteres', 'error')
        return redirect(url_for('admin'))
    if new_pass != confirm:
        flash('Senhas não coincidem', 'error')
        return redirect(url_for('admin'))
    proc = subprocess.run(
        ['sudo', 'chpasswd'],
        input=f'{user}:{new_pass}',
        capture_output=True, text=True
    )
    if proc.returncode != 0:
        flash('Erro ao alterar senha', 'error')
    else:
        subprocess.run(
            ['sudo', 'smbpasswd', '-s', user],
            input=f'{new_pass}\n{new_pass}\n',
            capture_output=True, text=True
        )
        flash('Senha alterada com sucesso', 'success')
    return redirect(url_for('admin'))

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
    notice_file = os.path.join(PORTAL_DIR, 'notice.html')
    notice = open(notice_file).read() if os.path.exists(notice_file) else ''
    return render_template_string(
        ADMIN_T, notice=notice, session=session,
        admin_users=ADMIN_USERS, banner=get_banner()
    )

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
    dest = os.path.join(BANNER_DIR, f'banner{ext}')
    f.save(dest)
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
    username    = request.form.get('username', username).strip()
    new_pass    = request.form.get('new_pass', '')
    confirm     = request.form.get('confirm_pass', '')
    if not username or not re.match(r'^[a-z][a-z0-9_-]{0,31}$', username):
        return jsonify({'ok': False, 'error': 'Usuário inválido'})
    if len(new_pass) < 8:
        return jsonify({'ok': False, 'error': 'Mínimo 8 caracteres'})
    if new_pass != confirm:
        return jsonify({'ok': False, 'error': 'Senhas não coincidem'})
    proc = subprocess.run(
        ['sudo', 'chpasswd'],
        input=f'{username}:{new_pass}',
        capture_output=True, text=True
    )
    if proc.returncode != 0:
        return jsonify({'ok': False, 'error': f'chpasswd: {proc.stderr.strip()}'})
    subprocess.run(
        ['sudo', 'smbpasswd', '-s', username],
        input=f'{new_pass}\n{new_pass}\n',
        capture_output=True, text=True
    )
    return jsonify({'ok': True, 'message': f'Senha de {username} atualizada'})

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000, debug=False)
