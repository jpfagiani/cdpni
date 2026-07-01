#!/bin/bash
# Cria grupos Linux que existem no smb.conf mas não no sistema,
# depois aplica chown/chmod recursivo nas pastas dos shares.
set -e

if [[ $EUID -ne 0 ]]; then
    echo "Execute como root: sudo bash fix_missing_groups.sh"
    exit 1
fi

python3 << 'PYEOF'
import re, os, subprocess, grp as grpmod

conf_path = '/etc/samba/smb.conf'
with open(conf_path) as f:
    content = f.read()

SKIP = {'global', 'recycle', 'homes', 'printers'}

def group_exists(name):
    try:
        grpmod.getgrnam(name)
        return True
    except KeyError:
        return False

for m in re.finditer(r'\[([^\]]+)\]\s*\n(.*?)(?=\[|\Z)', content, re.DOTALL):
    share_name = m.group(1).strip()
    body       = m.group(2)
    if share_name.lower() in SKIP:
        continue

    # Lê grupo de 'force group' ou 'valid users = @grupo'
    fg = re.search(r'^\s*force group\s*=\s*(\S+)', body, re.MULTILINE)
    if fg:
        grp = fg.group(1).lstrip('+')
    else:
        vu = re.search(r'^\s*valid users\s*=.*?@(\S+)', body, re.MULTILINE)
        grp = vu.group(1) if vu else 'grp_' + share_name.lower()

    pm = re.search(r'^\s*path\s*=\s*(.+)', body, re.MULTILINE)
    if not pm:
        continue
    path = pm.group(1).strip()

    # Cria o grupo se não existir
    if not group_exists(grp):
        print(f'  Criando grupo: {grp}')
        subprocess.run(['groupadd', '--system', grp])
    else:
        print(f'  Grupo OK: {grp}')

    if not os.path.isdir(path):
        print(f'    AVISO: {path} não existe — pulando')
        continue

    # Aplica chown e chmod recursivo
    print(f'    chown -R :{grp}  chmod -R g+rw  {path}')
    subprocess.run(['chown', '-R', f':{grp}', path])
    subprocess.run(['find', path, '-type', 'f', '-exec', 'chmod', 'g+rw', '{}', '+'])
    subprocess.run(['find', path, '-type', 'd', '-exec', 'chmod', 'g+rwx', '{}', '+'])

print()
print('Concluído.')
PYEOF

echo ""
echo "==> Reiniciando smbd para aplicar force group..."
systemctl restart smbd
systemctl is-active smbd && echo "    OK: smbd ativo"
