<?php
require_once dirname(__DIR__, 2) . '/config.php';
session_start();
header('Content-Type: application/json; charset=utf-8');

function json_out($d,$c=200){http_response_code($c);echo json_encode($d,JSON_UNESCAPED_UNICODE);exit;}
function run($cmd){$o=[];$r=0;exec($cmd.' 2>&1',$o,$r);return['output'=>implode("\n",$o),'code'=>$r];}
function log_action($m){file_put_contents(LOG_FILE,date('[Y-m-d H:i:s]').' ['.($_SESSION['user']??'?').'] '.$m."\n",FILE_APPEND);}
function require_auth(){if(empty($_SESSION['auth']))json_out(['error'=>'Não autenticado'],401);}
function sanitize_user($s){return preg_replace('/[^a-z0-9_]/','',strtolower(trim($s)));}
function sanitize_group($s){return preg_replace('/[^a-z0-9_]/','',strtolower(trim($s)));}

$action=$_GET['action']??$_POST['action']??'';

if($action==='login'){
    $hash=defined('PANEL_PASS_CURRENT')?PANEL_PASS_CURRENT:PANEL_PASS;
    if(($_POST['user']??'')===PANEL_USER&&password_verify($_POST['pass']??'',$hash)){
        $_SESSION['user']=$_POST['user'];
        $is_default=!file_exists(PASS_FILE)&&password_verify($_POST['pass']??'',PANEL_PASS);
        if($is_default){
            $_SESSION['must_change']=true;$_SESSION['auth']=false;
            json_out(['ok'=>true,'must_change'=>true,'message'=>'Troque a senha padrão para continuar.']);
        }
        $_SESSION['auth']=true;$_SESSION['must_change']=false;
        log_action('Login');json_out(['ok'=>true,'must_change'=>false]);
    }
    json_out(['error'=>'Usuário ou senha inválidos'],401);
}
if($action==='logout'){session_destroy();json_out(['ok'=>true]);}

if($action==='change_panel_pass'){
    if(empty($_SESSION['auth'])&&empty($_SESSION['must_change']))json_out(['error'=>'Não autenticado'],401);
    $old=$_POST['old']??'';$new=$_POST['new']??'';$confirm=$_POST['confirm']??'';
    $hash=defined('PANEL_PASS_CURRENT')?PANEL_PASS_CURRENT:PANEL_PASS;
    if(!password_verify($old,$hash))json_out(['error'=>'Senha atual incorreta'],400);
    if(strlen($new)<6)json_out(['error'=>'Mínimo 6 caracteres'],400);
    if($new!==$confirm)json_out(['error'=>'Senhas não coincidem'],400);
    $h=password_hash($new,PASSWORD_BCRYPT);
    file_put_contents(PASS_FILE,"<?php define('PANEL_PASS_CURRENT',".var_export($h,true)."); ?>");
    $_SESSION['must_change']=false;$_SESSION['auth']=true;
    log_action('Senha do painel alterada');
    json_out(['ok'=>true,'message'=>'Senha alterada!']);
}

require_auth();

if($action==='list_users'){
    $out=run('sudo pdbedit -L -v 2>/dev/null');$users=[];$cur=[];
    foreach(explode("\n",$out['output'])as$l){
        if(preg_match('/^Unix username:\s+(.+)/',$l,$m)){if($cur)$users[]=$cur;$cur=['user'=>trim($m[1]),'fullname'=>'','status'=>'Ativo','groups'=>[]];}
        elseif(preg_match('/^Full Name:\s+(.*)/',$l,$m)&&$cur)$cur['fullname']=trim($m[1]);
        elseif(preg_match('/^Account Flags:\s+\[(.+)\]/',$l,$m)&&$cur)$cur['status']=str_contains($m[1],'D')?'Desabilitado':'Ativo';
    }
    if($cur)$users[]=$cur;
    foreach($users as&$u){
        $g=run('id -nG '.escapeshellarg($u['user']).' 2>/dev/null');
        $u['groups']=array_values(array_filter(explode(' ',trim($g['output']))));
    }
    json_out($users);
}
if($action==='create_user'){
    $user=sanitize_user($_POST['user']??'');
    $full=trim($_POST['fullname']??$user);
    $pass=$_POST['pass']??'1234';
    $groups=trim($_POST['groups']??'grp_publico');
    if(!$user)json_out(['error'=>'Nome inválido'],400);
    if(strlen($pass)<4)json_out(['error'=>'Senha mínima 4 caracteres'],400);
    $primary=explode(',',$groups)[0]??'grp_publico';
    $extra=implode(',',array_slice(explode(',',$groups),1));
    $cmd='sudo useradd -m -c '.escapeshellarg($full).' -s /usr/sbin/nologin -g '.escapeshellarg($primary);
    if($extra)$cmd.=' -G '.escapeshellarg($extra);
    run($cmd.' '.escapeshellarg($user));
    run('echo '.escapeshellarg("{$user}:{$pass}").' | sudo chpasswd');
    run("printf '%s\n%s\n' ".escapeshellarg($pass).' '.escapeshellarg($pass).' | sudo smbpasswd -s -a '.escapeshellarg($user));
    run('sudo smbpasswd -e '.escapeshellarg($user));
    $rec=RECYCLE_DIR."/{$user}";
    run('sudo mkdir -p '.escapeshellarg($rec));
    run('sudo chmod 700 '.escapeshellarg($rec));
    run('sudo chown '.escapeshellarg("{$user}:{$primary}").' '.escapeshellarg($rec));
    log_action("Usuário criado: {$user}");
    json_out(['ok'=>true,'message'=>"Usuário {$user} criado com sucesso"]);
}
if($action==='delete_user'){
    $user=sanitize_user($_POST['user']??'');
    if(!$user)json_out(['error'=>'Inválido'],400);
    run('sudo smbpasswd -x '.escapeshellarg($user).' 2>/dev/null');
    run('sudo userdel -r '.escapeshellarg($user).' 2>/dev/null');
    $rec=RECYCLE_DIR."/{$user}";
    if(is_dir($rec)) run('sudo rm -rf '.escapeshellarg($rec));
    log_action("Usuário excluído: {$user}");
    json_out(['ok'=>true]);
}
if($action==='reset_pass'){
    $user=sanitize_user($_POST['user']??'');
    $pass=$_POST['pass']??'1234';
    if(!$user)json_out(['error'=>'Inválido'],400);
    if(strlen($pass)<4)json_out(['error'=>'Mínimo 4 caracteres'],400);
    run('echo '.escapeshellarg("{$user}:{$pass}").' | sudo chpasswd');
    run("printf '%s\n%s\n' ".escapeshellarg($pass).' '.escapeshellarg($pass).' | sudo smbpasswd -s '.escapeshellarg($user));
    log_action("Senha resetada: {$user}");
    json_out(['ok'=>true]);
}
if($action==='toggle_user'){
    $user=sanitize_user($_POST['user']??'');
    $enable=($_POST['enable']??'0')==='1';
    if(!$user)json_out(['error'=>'Inválido'],400);
    if($enable){run('sudo smbpasswd -e '.escapeshellarg($user));}
    else{run('sudo smbpasswd -d '.escapeshellarg($user));}
    log_action(($enable?'Habilitado':'Desabilitado').": {$user}");
    json_out(['ok'=>true]);
}
if($action==='list_groups'){
    $out=run("getent group | grep '^grp_'");
    $groups=[];
    foreach(explode("\n",$out['output'])as$line){
        if(!$line)continue;
        $p=explode(':',$line);
        $groups[]=['name'=>$p[0],'gid'=>$p[2],'members'=>$p[3]?array_values(array_filter(explode(',',$p[3]))):[]];
    }
    json_out($groups);
}
if($action==='create_group'){
    $name='grp_'.sanitize_group($_POST['name']??'');
    if($name==='grp_')json_out(['error'=>'Nome inválido'],400);
    $r=run('sudo groupadd '.escapeshellarg($name).' 2>&1');
    if($r['code']!==0&&str_contains($r['output'],'already exists'))json_out(['error'=>'Grupo já existe'],409);
    log_action("Grupo criado: {$name}");
    json_out(['ok'=>true,'message'=>"Grupo {$name} criado"]);
}
if($action==='add_to_group'){
    $user=sanitize_user($_POST['user']??'');
    $group=sanitize_group($_POST['group']??'');
    if(!$user||!$group)json_out(['error'=>'Dados inválidos'],400);
    run('sudo usermod -aG '.escapeshellarg($group).' '.escapeshellarg($user));
    log_action("{$user} adicionado ao grupo {$group}");
    json_out(['ok'=>true]);
}
if($action==='remove_from_group'){
    $user=sanitize_user($_POST['user']??'');
    $group=sanitize_group($_POST['group']??'');
    if(!$user||!$group)json_out(['error'=>'Dados inválidos'],400);
    run('sudo gpasswd -d '.escapeshellarg($user).' '.escapeshellarg($group).' 2>&1');
    log_action("{$user} removido do grupo {$group}");
    json_out(['ok'=>true]);
}
if($action==='delete_group'){
    $group=sanitize_group($_POST['group']??'');
    if(!$group)json_out(['error'=>'Grupo inválido'],400);
    $protected=['grp_publico','grp_cpd','grp_administrativo'];
    if(in_array($group,$protected))json_out(['error'=>'Grupo protegido — não pode ser excluído'],403);
    $r=run('sudo groupdel '.escapeshellarg($group).' 2>&1');
    if($r['code']!==0&&!str_contains($r['output'],'does not exist'))
        json_out(['error'=>'Erro ao excluir: '.$r['output']],500);
    log_action("Grupo excluído: {$group}");
    json_out(['ok'=>true,'message'=>"Grupo {$group} excluído"]);
}
if($action==='list_shares'){
    $conf=file_get_contents(SMB_CONF);
    $shares=[];
    preg_match_all('/^\[([^\]]+)\]/m',$conf,$names);
    foreach($names[1] as $name){
        if(in_array(strtolower($name),['global','printers','print$','recycle']))continue;
        preg_match('/\['.preg_quote($name,'/').'\].*?(?=\n\[|\z)/s',$conf,$block);
        $b=$block[0]??'';
        $path=preg_match('/path\s*=\s*(.+)/i',$b,$m)?trim($m[1]):'';
        $size='';
        if($path&&is_dir($path)){
            $df=shell_exec('df -h '.escapeshellarg($path).' 2>/dev/null | tail -1');
            $p=preg_split('/\s+/',trim($df??''));
            $size=($p[2]??'').'/'.($p[1]??'');
        }
        $shares[]=[
            'name'=>$name,'path'=>$path,
            'comment'=>preg_match('/comment\s*=\s*(.+)/i',$b,$m)?trim($m[1]):'',
            'writable'=>(bool)preg_match('/writable\s*=\s*yes/i',$b),
            'browse'=>!preg_match('/browseable\s*=\s*no/i',$b),
            'size'=>$size
        ];
    }
    json_out($shares);
}
if($action==='create_share'){
    $name=preg_replace('/[^a-zA-Z0-9_\-]/','',trim($_POST['name']??''));
    $group=sanitize_group($_POST['group']??'');
    $comment=htmlspecialchars(trim($_POST['comment']??$name),ENT_QUOTES,'UTF-8');
    $writable=($_POST['writable']??'1')==='1'?'yes':'no';
    $browse=($_POST['browse']??'1')==='1'?'yes':'no';
    if(!$name||!$group)json_out(['error'=>'Nome e grupo obrigatórios'],400);
    $path=SAMBA_ROOT."/{$name}";
    run('sudo mkdir -p '.escapeshellarg($path));
    run('sudo chmod -R 777 '.escapeshellarg($path));
    $entry="\n[{$name}]\n    comment      = {$comment}\n    path         = {$path}\n    valid users  = @{$group} ".PANEL_USER."\n    writable     = {$writable}\n    browseable   = {$browse}\n    create mask  = 0664\n    directory mask = 0777\n    force create mode = 0664\n    force directory mode = 0777\n";
    file_put_contents(SMB_CONF,$entry,FILE_APPEND);
    $t=run('sudo testparm -s '.escapeshellarg(SMB_CONF).' 2>&1');
    if(str_contains($t['output'],'FATAL'))json_out(['error'=>'Erro smb.conf'],500);
    run('sudo systemctl reload smbd 2>/dev/null || sudo systemctl restart smbd');
    log_action("Share criado: {$name}");
    json_out(['ok'=>true,'message'=>"Share {$name} criado"]);
}
if($action==='delete_share'){
    $name=preg_replace('/[^a-zA-Z0-9_\-]/','',trim($_POST['name']??''));
    $del_dir=($_POST['del_dir']??'0')==='1';
    if(!$name)json_out(['error'=>'Nome inválido'],400);
    $protected=['global','printers','print$','recycle'];
    if(in_array(strtolower($name),$protected))json_out(['error'=>'Share protegida'],403);
    $conf=file_get_contents(SMB_CONF);
    $new=preg_replace('/\n\['.preg_quote($name,'/').'(?:\s*\]\s*\n(?!.*\[)[^\[]*)/s','',$conf);
    $new=preg_replace('/\['.preg_quote($name,'/').'\][^\[]*/s','',$new);
    file_put_contents(SMB_CONF,trim($new)."\n");
    $t=run('sudo testparm -s '.escapeshellarg(SMB_CONF).' 2>&1');
    if(str_contains($t['output'],'FATAL')){
        file_put_contents(SMB_CONF,$conf);
        json_out(['error'=>'Erro no smb.conf após remoção — revertido'],500);
    }
    run('sudo systemctl reload smbd 2>/dev/null || sudo systemctl restart smbd');
    if($del_dir){
        $path=SAMBA_ROOT."/{$name}";
        if(is_dir($path))run('sudo rm -rf '.escapeshellarg($path));
    }
    log_action("Share excluída: {$name}".($del_dir?' (diretório removido)':''));
    json_out(['ok'=>true,'message'=>"Share {$name} removida".($del_dir?' e diretório excluído':'')]);
}
if($action==='status'){
    $smbd=run('systemctl is-active smbd 2>/dev/null');
    $nmbd=run('systemctl is-active nmbd 2>/dev/null');
    $raid=run('cat /proc/mdstat 2>/dev/null | head -8');
    $disk=run('df -h '.escapeshellarg(SAMBA_ROOT).' 2>/dev/null | tail -1');
    $conns=run('sudo smbstatus -S 2>/dev/null | grep -cv "^\$\|^-\|^Share" 2>/dev/null || echo 0');
    $uptime=run('uptime -p 2>/dev/null');
    $p=preg_split('/\s+/',trim($disk['output']??''));
    json_out([
        'smbd'=>trim($smbd['output']),
        'nmbd'=>trim($nmbd['output']),
        'disk_used'=>$p[2]??'-',
        'disk_total'=>$p[1]??'-',
        'disk_pct'=>$p[4]??'-',
        'connections'=>max(0,(int)trim($conns['output'])-1),
        'uptime'=>trim($uptime['output']),
        'raid'=>trim($raid['output'])
    ]);
}
json_out(['error'=>'Ação desconhecida'],404);
