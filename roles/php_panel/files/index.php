<?php
require_once dirname(__DIR__) . '/config.php';
session_start();
$logged = !empty($_SESSION['auth']);
?>
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>CDPNI — Painel Admin</title>
<style>
:root{--bg:#0d1b2e;--bg2:#112240;--bg3:#163052;--border:#1e4070;--text:#d4e8f8;--muted:#5a8ab4;--accent:#3a8fff;--accent2:#1a6fdf;--danger:#ff5a5a;--success:#3fd87a;--warning:#ffb830;--font:-apple-system,BlinkMacSystemFont,'Segoe UI',system-ui,sans-serif;--mono:'Consolas','Courier New',monospace}
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:var(--font);background:var(--bg);color:var(--text);min-height:100vh}
.login-wrap{display:flex;align-items:center;justify-content:center;min-height:100vh}
.login-box{background:var(--bg2);border:1px solid var(--border);border-radius:12px;overflow:hidden;width:340px}
.login-header{background:var(--bg3);border-bottom:1px solid var(--border);padding:20px;text-align:center}
.login-icon{width:48px;height:48px;background:linear-gradient(135deg,#1a6fdf,#3a8fff);border-radius:12px;display:inline-flex;align-items:center;justify-content:center;font-size:22px;margin-bottom:8px}
.login-header h1{font-size:16px;font-weight:600}.login-header p{font-size:12px;color:var(--muted);margin-top:2px}
.login-body{padding:20px;display:flex;flex-direction:column;gap:12px}
.form-group label{font-size:11px;color:var(--muted);display:block;margin-bottom:4px}
input[type=text],input[type=password],select{background:var(--bg);border:1px solid var(--border);border-radius:6px;padding:8px 12px;font-size:13px;color:var(--text);width:100%;outline:none;font-family:var(--font)}
input:focus,select:focus{border-color:var(--accent)}
.login-error{font-size:12px;color:var(--danger);padding:8px 12px;background:#2a0f0f;border:1px solid #4a1f1f;border-radius:6px;display:none}
.btn{padding:.45rem .9rem;border-radius:6px;border:1px solid var(--border);background:var(--bg3);color:var(--text);cursor:pointer;font-size:.8rem;font-family:var(--font);display:inline-flex;align-items:center;gap:.4rem}
.btn-primary{background:var(--accent2);border-color:var(--accent2);color:#fff;width:100%;justify-content:center;padding:.6rem}
.btn-primary:hover{background:#388bfd}.btn-danger{border-color:var(--danger);color:var(--danger)}.btn-sm{padding:.3rem .65rem;font-size:.75rem}
.layout{display:flex;height:100vh;overflow:hidden}
.sidebar{width:210px;min-width:210px;background:var(--bg2);border-right:1px solid var(--border);display:flex;flex-direction:column;padding:8px 6px;overflow-y:auto}
.sidebar-logo{padding:10px 10px 14px;border-bottom:1px solid var(--border);margin-bottom:6px;display:flex;align-items:center;gap:8px}
.sidebar-logo-icon{width:30px;height:30px;background:linear-gradient(135deg,#1a6fdf,#3a8fff);border-radius:8px;display:grid;place-items:center;font-size:14px;font-weight:700;color:#fff;flex-shrink:0}
.sidebar-logo h2{font-size:13px;font-weight:600}.sidebar-logo small{color:var(--muted);font-size:11px;display:block}
.nav-section{padding:8px 8px 3px}.nav-section span{font-size:10px;font-weight:700;letter-spacing:.08em;text-transform:uppercase;color:var(--muted)}
.nav-item{display:flex;align-items:center;gap:.5rem;padding:6px 10px;color:var(--muted);cursor:pointer;font-size:12px;font-weight:500;border-radius:6px;border:1px solid transparent;margin-bottom:1px}
.nav-item:hover{background:var(--bg3);color:var(--text)}.nav-item.active{background:#081828;color:var(--accent);border-color:#102840;font-weight:600}
.sidebar-footer{margin-top:auto;padding:10px 8px;border-top:1px solid var(--border)}
.logout-btn{width:100%;padding:.5rem;background:transparent;border:1px solid var(--border);border-radius:8px;color:var(--muted);cursor:pointer;font-size:.8rem;font-family:var(--font)}
.logout-btn:hover{border-color:var(--danger);color:var(--danger)}
.main{flex:1;display:flex;flex-direction:column;overflow:hidden}
.topbar{height:52px;border-bottom:1px solid var(--border);display:flex;align-items:center;padding:0 1.5rem;background:var(--bg2);gap:1rem}
.topbar h3{font-size:.95rem;font-weight:600;flex:1}
.content{flex:1;overflow-y:auto;padding:1.5rem}
.status-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(160px,1fr));gap:.75rem;margin-bottom:1.5rem}
.stat-card{background:var(--bg2);border:1px solid var(--border);border-top:3px solid var(--accent);border-radius:8px;padding:10px 12px}
.stat-card .label{font-size:.7rem;color:var(--muted);text-transform:uppercase;letter-spacing:.06em}
.stat-card .value{font-size:1.4rem;font-weight:600;margin-top:.25rem;font-family:var(--mono)}
.stat-card .sub{font-size:.75rem;color:var(--muted)}
.dot{display:inline-block;width:8px;height:8px;border-radius:50%;margin-right:4px}
.dot-green{background:var(--success)}.dot-red{background:var(--danger)}
.card{background:var(--bg2);border:1px solid var(--border);border-radius:8px;overflow:hidden;margin-bottom:1rem}
.card-header{padding:10px 14px;border-bottom:1px solid var(--border);display:flex;align-items:center;gap:.6rem;background:var(--bg3)}
.card-header h4{font-size:.9rem;font-weight:600;flex:1}
table{width:100%;border-collapse:collapse;font-size:.85rem}
th{padding:.625rem 1.25rem;text-align:left;font-size:.72rem;font-weight:600;text-transform:uppercase;letter-spacing:.06em;color:var(--muted);background:var(--bg3);border-bottom:1px solid var(--border)}
td{padding:.75rem 1.25rem;border-bottom:1px solid var(--border);vertical-align:middle}
tr:last-child td{border-bottom:none}tr:hover td{background:rgba(255,255,255,.02)}
.tag{display:inline-block;padding:.15rem .55rem;border-radius:4px;font-size:.72rem;font-family:var(--mono);background:var(--bg3);border:1px solid var(--border);color:var(--muted);margin:.1rem}
.tag-blue{background:rgba(31,111,235,.15);border-color:rgba(31,111,235,.3);color:#79b8ff}
.tag-green{background:#0a2518;border-color:#1a4a30;color:#3fd87a}.tag-red{background:#2a0f0f;border-color:#4a1f1f;color:#ff5a5a}
.form-group{margin-bottom:1rem}.form-group label{display:block;font-size:.8rem;color:var(--muted);margin-bottom:.35rem;font-weight:500}
.form-row{display:grid;grid-template-columns:1fr 1fr;gap:1rem}
.modal-overlay{display:none;position:fixed;inset:0;background:rgba(0,0,0,.6);backdrop-filter:blur(4px);z-index:100;align-items:center;justify-content:center}
.modal-overlay.open{display:flex}
.modal{background:var(--bg2);border:1px solid var(--border);border-radius:12px;width:480px;max-width:95vw;padding:1.5rem;box-shadow:0 24px 64px rgba(0,0,0,.5)}
.modal h3{font-size:1rem;font-weight:600;margin-bottom:1.25rem;padding-bottom:.75rem;border-bottom:1px solid var(--border)}
.modal-footer{display:flex;gap:.625rem;justify-content:flex-end;margin-top:1.25rem;padding-top:.75rem;border-top:1px solid var(--border)}
.toast-wrap{position:fixed;bottom:1.5rem;right:1.5rem;z-index:999;display:flex;flex-direction:column;gap:.5rem}
.toast{padding:.75rem 1.25rem;border-radius:8px;border:1px solid;font-size:.85rem;font-weight:500;max-width:320px}
.toast.success{background:#0a2518;border-color:#1a4a30;color:#3fd87a}.toast.error{background:#2a0f0f;border-color:#4a1f1f;color:#ff5a5a}
.empty{text-align:center;padding:3rem 1rem;color:var(--muted)}.empty .icon{font-size:2.5rem;display:block;margin-bottom:.75rem;opacity:.4}
::-webkit-scrollbar{width:6px}::-webkit-scrollbar-thumb{background:var(--border);border-radius:3px}
</style>
</head>
<body>
<?php if(!$logged): ?>
<div class="login-wrap"><div class="login-box">
  <div class="login-header"><div class="login-icon">📁</div><h1>CDPNI</h1><p>Painel Admin Samba</p></div>
  <div class="login-body">
    <div id="lE" class="login-error"></div>
    <div class="form-group"><label>Usuário</label><input type="text" id="lU" value="admin"></div>
    <div class="form-group"><label>Senha</label><input type="password" id="lP" placeholder="••••••••"></div>
    <button class="btn btn-primary" onclick="doLogin()">Entrar</button>
  </div>
</div></div>
<?php else: ?>
<div class="layout">
  <aside class="sidebar">
    <div class="sidebar-logo"><div class="sidebar-logo-icon">SB</div><div><h2>Samba CDPNI</h2><small>Painel Admin</small></div></div>
    <div class="nav-section"><span>Principal</span></div>
    <div class="nav-item active" onclick="goto('dashboard')"><span>🏠</span> Dashboard</div>
    <div class="nav-section"><span>Usuários e Grupos</span></div>
    <div class="nav-item" onclick="goto('users')"><span>👤</span> Usuários</div>
    <div class="nav-item" onclick="goto('groups')"><span>👥</span> Grupos</div>
    <div class="nav-section"><span>Compartilhamentos</span></div>
    <div class="nav-item" onclick="goto('shares')"><span>🗂️</span> Shares</div>
    <div class="sidebar-footer"><button class="logout-btn" onclick="doLogout()">⏻ Sair</button></div>
  </aside>
  <div class="main">
    <div class="topbar"><h3 id="pT">Dashboard</h3><button id="tA" class="btn btn-primary btn-sm" style="display:none"></button></div>
    <div class="content" id="ct"><p style="color:var(--muted)">Carregando...</p></div>
  </div>
</div>
<div class="modal-overlay" id="modal"><div class="modal"><h3 id="mT"></h3><div id="mB"></div><div class="modal-footer" id="mF"></div></div></div>
<div class="toast-wrap" id="toasts"></div>
<?php endif; ?>
<script>
const $=id=>document.getElementById(id);
const esc=s=>String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
function toast(msg,type='success'){const t=document.createElement('div');t.className='toast '+type;t.textContent=msg;$('toasts').appendChild(t);setTimeout(()=>t.remove(),3500);}
async function api(action,data={},method='GET'){
  const isGet=method==='GET';
  const opts={method,credentials:'same-origin'};
  if(!isGet){const fd=new FormData();fd.append('action',action);Object.entries(data).forEach(([k,v])=>fd.append(k,v));opts.body=fd;}
  const res=await fetch(isGet?`api/?action=${action}`:'api/',opts);
  const json=await res.json();
  if(json.error)throw new Error(json.error);
  return json;
}
function modal(title,body,btns=[]){
  $('mT').textContent=title;$('mB').innerHTML=body;$('mF').innerHTML='';
  btns.forEach(b=>{const el=document.createElement('button');el.className='btn '+(b.cls||'');el.textContent=b.label;el.onclick=b.fn;$('mF').appendChild(el);});
  $('modal').classList.add('open');
}
function closeModal(){$('modal').classList.remove('open');}
$('modal')?.addEventListener('click',e=>{if(e.target===$('modal'))closeModal();});

async function doLogin(){
  const btn=document.querySelector('.btn-primary');btn.disabled=true;btn.textContent='Entrando...';
  try{
    const r=await api('login',{user:$('lU').value,pass:$('lP').value},'POST');
    if(r.must_change){
      document.querySelector('.login-box').innerHTML=`
        <div class="login-header"><div class="login-icon">🔑</div><h1>Troca Obrigatória</h1><p style="color:var(--warning)">${r.message}</p></div>
        <div class="login-body">
          <div id="cpE" class="login-error"></div>
          <div class="form-group"><label>Senha Atual</label><input type="password" id="cpO"></div>
          <div class="form-group"><label>Nova Senha</label><input type="password" id="cpN" placeholder="mín. 6 caracteres"></div>
          <div class="form-group"><label>Confirmar</label><input type="password" id="cpC"></div>
          <button class="btn btn-primary" onclick="doChangePass()">Salvar</button>
        </div>`;
    } else location.reload();
  }catch(e){$('lE').textContent=e.message;$('lE').style.display='block';btn.disabled=false;btn.textContent='Entrar';}
}
async function doChangePass(){
  try{await api('change_panel_pass',{old:$('cpO').value,new:$('cpN').value,confirm:$('cpC').value},'POST');location.reload();}
  catch(e){$('cpE').textContent=e.message;$('cpE').style.display='block';}
}
async function doLogout(){await api('logout',{},'POST');location.reload();}

const pages={
  dashboard:{title:'Dashboard',action:null},
  users:{title:'Usuários',action:{label:'+ Novo Usuário',fn:'openCreateUser'}},
  groups:{title:'Grupos',action:{label:'+ Novo Grupo',fn:'openCreateGroup'}},
  shares:{title:'Compartilhamentos',action:{label:'+ Novo Share',fn:'openCreateShare'}}
};
function goto(page){
  document.querySelectorAll('.nav-item').forEach(n=>n.classList.toggle('active',n.getAttribute('onclick')?.includes(`'${page}'`)));
  const p=pages[page];$('pT').textContent=p.title;
  const btn=$('tA');
  if(p.action){btn.style.display='';btn.textContent=p.action.label;btn.onclick=()=>window[p.action.fn]();}
  else btn.style.display='none';
  renders[page]?.();
}
const renders={
  async dashboard(){
    try{
      const s=await api('status');
      const ok=v=>v==='active';
      $('ct').innerHTML=`
        <div class="status-grid">
          <div class="stat-card"><div class="label">Samba (smbd)</div><div class="value" style="font-size:1rem;margin-top:.4rem"><span class="dot ${ok(s.smbd)?'dot-green':'dot-red'}"></span>${ok(s.smbd)?'Ativo':'Inativo'}</div></div>
          <div class="stat-card"><div class="label">NetBIOS (nmbd)</div><div class="value" style="font-size:1rem;margin-top:.4rem"><span class="dot ${ok(s.nmbd)?'dot-green':'dot-red'}"></span>${ok(s.nmbd)?'Ativo':'Inativo'}</div></div>
          <div class="stat-card"><div class="label">Espaço Usado</div><div class="value">${esc(s.disk_used||'-')}</div><div class="sub">de ${esc(s.disk_total||'-')} (${esc(s.disk_pct||'-')})</div></div>
          <div class="stat-card"><div class="label">Conexões</div><div class="value">${esc(s.connections)}</div></div>
          <div class="stat-card" style="grid-column:span 2"><div class="label">Uptime</div><div class="value" style="font-size:.95rem;margin-top:.35rem">${esc(s.uptime||'-')}</div></div>
        </div>
        <div class="card"><div class="card-header"><h4>Status RAID</h4></div>
        <pre style="padding:1rem 1.25rem;font-family:var(--mono);font-size:.78rem;color:var(--muted);white-space:pre-wrap">${esc(s.raid||'N/D')}</pre></div>`;
    }catch(e){$('ct').innerHTML=`<div class="empty"><span class="icon">⚠️</span>${esc(e.message)}</div>`;}
  },
  async users(){
    try{
      const u=await api('list_users');
      if(!u.length){$('ct').innerHTML='<div class="empty"><span class="icon">👤</span>Nenhum usuário</div>';return;}
      $('ct').innerHTML=`<div class="card"><div class="card-header"><h4>Usuários Samba (${u.length})</h4></div>
        <table><thead><tr><th>Login</th><th>Nome</th><th>Status</th><th>Grupos</th><th style="text-align:right">Ações</th></tr></thead>
        <tbody>${u.map(x=>`<tr>
          <td><span style="font-family:var(--mono);font-weight:500">${esc(x.user)}</span></td>
          <td style="color:var(--muted)">${esc(x.fullname||'-')}</td>
          <td>${x.status==='Ativo'?'<span class="tag tag-green">Ativo</span>':'<span class="tag tag-red">Desabilitado</span>'}</td>
          <td>${x.groups.map(g=>`<span class="tag tag-blue">${esc(g)}</span>`).join('')||'-'}</td>
          <td style="text-align:right;white-space:nowrap">
            <button class="btn btn-sm" onclick="openResetPass('${esc(x.user)}')">🔑 Senha</button>
            <button class="btn btn-sm" onclick="toggleUser('${esc(x.user)}','${x.status}')">${x.status==='Ativo'?'⏸ Bloquear':'▶ Ativar'}</button>
            <button class="btn btn-sm btn-danger" onclick="deleteUser('${esc(x.user)}')">🗑</button>
          </td>
        </tr>`).join('')}</tbody></table></div>`;
    }catch(e){$('ct').innerHTML=`<div class="empty"><span class="icon">⚠️</span>${esc(e.message)}</div>`;}
  },
  async groups(){
    try{
      const g=await api('list_groups');
      if(!g.length){$('ct').innerHTML='<div class="empty"><span class="icon">👥</span>Nenhum grupo</div>';return;}
      $('ct').innerHTML=`<div class="card"><div class="card-header"><h4>Grupos (${g.length})</h4></div>
        <table><thead><tr><th>Grupo</th><th>GID</th><th>Membros</th><th style="text-align:right">Ações</th></tr></thead>
        <tbody>${g.map(x=>`<tr>
          <td><span style="font-family:var(--mono);font-weight:500">${esc(x.name)}</span></td>
          <td style="color:var(--muted);font-family:var(--mono)">${esc(x.gid)}</td>
          <td style="max-width:320px">${x.members.length
            ? x.members.map(m=>`<span class="tag" style="display:inline-flex;align-items:center;gap:.25rem">${esc(m)}<button title="Remover do grupo" onclick="removeMember('${esc(m)}','${esc(x.name)}')" style="background:none;border:none;cursor:pointer;color:var(--danger);font-size:.85rem;line-height:1;padding:0">×</button></span>`).join('')
            : '<span style="color:var(--muted);font-size:.8rem">sem membros</span>'}</td>
          <td style="text-align:right;white-space:nowrap">
            <button class="btn btn-sm" onclick="openAddMember('${esc(x.name)}')">+ Membro</button>
            <button class="btn btn-sm btn-danger" onclick="deleteGroup('${esc(x.name)}')">🗑 Excluir</button>
          </td>
        </tr>`).join('')}</tbody></table></div>`;
    }catch(e){$('ct').innerHTML=`<div class="empty"><span class="icon">⚠️</span>${esc(e.message)}</div>`;}
  },
  async shares(){
    try{
      const s=await api('list_shares');
      if(!s.length){$('ct').innerHTML='<div class="empty"><span class="icon">🗂️</span>Nenhum share</div>';return;}
      $('ct').innerHTML=`<div class="card"><div class="card-header"><h4>Compartilhamentos (${s.length})</h4></div>
        <table><thead><tr><th>Nome</th><th>Caminho</th><th>Disco</th><th>Flags</th><th style="text-align:right">Ações</th></tr></thead>
        <tbody>${s.map(x=>`<tr>
          <td><span style="font-family:var(--mono);font-weight:500">${esc(x.name)}</span></td>
          <td style="color:var(--muted);font-size:.8rem;font-family:var(--mono)">${esc(x.path)}</td>
          <td style="font-family:var(--mono);font-size:.8rem">${esc(x.size||'-')}</td>
          <td>${x.writable?'<span class="tag tag-green">gravável</span>':'<span class="tag">leitura</span>'} ${x.browse?'<span class="tag">visível</span>':'<span class="tag tag-red">oculto</span>'}</td>
          <td style="text-align:right"><button class="btn btn-sm btn-danger" onclick="deleteShare('${esc(x.name)}','${esc(x.path)}')">🗑 Excluir</button></td>
        </tr>`).join('')}</tbody></table></div>`;
    }catch(e){$('ct').innerHTML=`<div class="empty"><span class="icon">⚠️</span>${esc(e.message)}</div>`;}
  }
};

async function loadGrps(){
  try{const g=await api('list_groups');return g.map(x=>`<option value="${esc(x.name)}">${esc(x.name)}</option>`).join('');}
  catch{return '';}
}
async function openCreateUser(){
  const opts=await loadGrps();
  modal('Novo Usuário',`
    <div class="form-row">
      <div class="form-group"><label>Login *</label><input type="text" id="nU" placeholder="ex: joao"></div>
      <div class="form-group"><label>Nome Completo</label><input type="text" id="nF"></div>
    </div>
    <div class="form-row">
      <div class="form-group"><label>Senha inicial</label><input type="password" id="nP" placeholder="mín. 4 caracteres"></div>
      <div class="form-group"><label>Grupo Principal *</label><select id="nG">${opts}</select></div>
    </div>`,[
    {label:'Cancelar',fn:closeModal},
    {label:'Criar',cls:'btn-primary',fn:async()=>{
      const user=$('nU').value.trim();
      if(!user)return toast('Informe o login','error');
      try{await api('create_user',{user,fullname:$('nF').value,pass:$('nP').value||'1234',groups:$('nG').value},'POST');toast(`Usuário ${user} criado`);closeModal();renders.users();}
      catch(e){toast(e.message,'error');}
    }}]);
}
function openResetPass(user){
  modal(`Resetar Senha — ${user}`,`<div class="form-group"><label>Nova Senha</label><input type="password" id="rP" placeholder="mín. 4 caracteres"></div>`,[
    {label:'Cancelar',fn:closeModal},
    {label:'Salvar',cls:'btn-primary',fn:async()=>{
      const pass=$('rP').value;
      if(!pass||pass.length<4)return toast('Mínimo 4 caracteres','error');
      try{await api('reset_pass',{user,pass},'POST');toast('Senha atualizada');closeModal();}
      catch(e){toast(e.message,'error');}
    }}]);
}
async function toggleUser(user,status){
  try{await api('toggle_user',{user,enable:status!=='Ativo'?'1':'0'},'POST');toast(`${user} ${status!=='Ativo'?'habilitado':'bloqueado'}`);renders.users();}
  catch(e){toast(e.message,'error');}
}
function deleteUser(user){
  modal(`Excluir Usuário — ${user}`,`
    <p style="color:var(--muted);margin-bottom:.75rem">O usuário <strong style="color:var(--text)">${esc(user)}</strong> será <strong style="color:var(--danger)">permanentemente excluído</strong> do sistema e do Samba. Esta ação não pode ser desfeita.</p>
    <p style="font-size:.8rem;color:var(--muted)">Os arquivos do perfil do usuário serão removidos.</p>`,[
    {label:'Cancelar',fn:closeModal},
    {label:'Excluir permanentemente',cls:'btn-danger',fn:async()=>{
      try{await api('delete_user',{user},'POST');toast(`Usuário ${user} excluído`);closeModal();renders.users();}
      catch(e){toast(e.message,'error');}
    }}]);
}
async function removeMember(user,group){
  if(!confirm(`Remover "${user}" do grupo "${group}"?`))return;
  try{await api('remove_from_group',{user,group},'POST');toast(`${user} removido de ${group}`);renders.groups();}
  catch(e){toast(e.message,'error');}
}
function deleteGroup(group){
  modal(`Excluir Grupo — ${group}`,`
    <p style="color:var(--muted)">O grupo <strong style="color:var(--text)">${esc(group)}</strong> será excluído do sistema.</p>
    <p style="font-size:.8rem;color:var(--warning);margin-top:.5rem">⚠ Os usuários membros <strong>não</strong> serão excluídos, mas perderão o acesso às pastas que dependem deste grupo.</p>`,[
    {label:'Cancelar',fn:closeModal},
    {label:'Excluir grupo',cls:'btn-danger',fn:async()=>{
      try{await api('delete_group',{group},'POST');toast(`Grupo ${group} excluído`);closeModal();renders.groups();}
      catch(e){toast(e.message,'error');}
    }}]);
}
function deleteShare(name,path){
  modal(`Excluir Compartilhamento — ${name}`,`
    <p style="color:var(--muted);margin-bottom:.75rem">O share <strong style="color:var(--text)">${esc(name)}</strong> será removido do Samba.</p>
    <div class="form-group" style="margin-top:.75rem">
      <label style="display:flex;align-items:center;gap:.5rem;cursor:pointer">
        <input type="checkbox" id="delDir" style="width:auto">
        <span>Também <strong style="color:var(--danger)">excluir os arquivos</strong> em <code style="font-size:.8rem">${esc(path)}</code></span>
      </label>
    </div>`,[
    {label:'Cancelar',fn:closeModal},
    {label:'Excluir share',cls:'btn-danger',fn:async()=>{
      const del_dir=document.getElementById('delDir')?.checked?'1':'0';
      try{await api('delete_share',{name,del_dir},'POST');toast(`Share ${name} removido`);closeModal();renders.shares();}
      catch(e){toast(e.message,'error');}
    }}]);
}
function openCreateGroup(){
  modal('Novo Grupo',`<div class="form-group"><label>Nome (será prefixado com grp_) *</label><input type="text" id="gN" placeholder="ex: financeiro"></div>`,[
    {label:'Cancelar',fn:closeModal},
    {label:'Criar',cls:'btn-primary',fn:async()=>{
      const name=$('gN').value.trim();
      if(!name)return toast('Informe o nome','error');
      try{await api('create_group',{name},'POST');toast(`Grupo grp_${name} criado`);closeModal();renders.groups();}
      catch(e){toast(e.message,'error');}
    }}]);
}
async function openAddMember(group){
  modal(`Adicionar Membro — ${group}`,`<div class="form-group"><label>Login do usuário *</label><input type="text" id="mU" placeholder="ex: joao"></div>`,[
    {label:'Cancelar',fn:closeModal},
    {label:'Adicionar',cls:'btn-primary',fn:async()=>{
      const user=$('mU').value.trim();
      if(!user)return toast('Informe o usuário','error');
      try{await api('add_to_group',{user,group},'POST');toast(`${user} adicionado ao ${group}`);closeModal();renders.groups();}
      catch(e){toast(e.message,'error');}
    }}]);
}
async function openCreateShare(){
  const opts=await loadGrps();
  modal('Novo Compartilhamento',`
    <div class="form-row">
      <div class="form-group"><label>Nome *</label><input type="text" id="sN" placeholder="ex: Financeiro2025"></div>
      <div class="form-group"><label>Grupo *</label><select id="sG">${opts}</select></div>
    </div>
    <div class="form-group"><label>Descrição</label><input type="text" id="sC"></div>
    <div class="form-row">
      <div class="form-group"><label>Gravável</label><select id="sW"><option value="1">Sim</option><option value="0">Não</option></select></div>
      <div class="form-group"><label>Visível na rede</label><select id="sB"><option value="1">Sim</option><option value="0">Não (oculto)</option></select></div>
    </div>`,[
    {label:'Cancelar',fn:closeModal},
    {label:'Criar',cls:'btn-primary',fn:async()=>{
      const name=$('sN').value.trim(),group=$('sG').value;
      if(!name||!group)return toast('Nome e grupo obrigatórios','error');
      try{await api('create_share',{name,group,comment:$('sC').value,writable:$('sW').value,browse:$('sB').value},'POST');toast(`Share ${name} criado`);closeModal();renders.shares();}
      catch(e){toast(e.message,'error');}
    }}]);
}
<?php if($logged): ?>goto('dashboard');<?php endif; ?>
</script>
</body>
</html>
