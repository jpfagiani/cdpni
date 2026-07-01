#!/bin/bash
# Corrige force group de cada share para usar o mesmo grupo do valid_users
set -e

if [[ $EUID -ne 0 ]]; then
    echo "Execute como root: sudo bash fix_force_group.sh"
    exit 1
fi

BACKUP=/etc/samba/smb.conf.bak.$(date +%s)
echo "==> Backup: $BACKUP"
cp /etc/samba/smb.conf "$BACKUP"

python3 << 'PYEOF'
import re

conf_path = '/etc/samba/smb.conf'
with open(conf_path) as f:
    content = f.read()

SKIP = {'global', 'recycle', 'homes', 'printers'}

def fix_section(m):
    header     = m.group(1)
    share_name = m.group(2).strip()
    body       = m.group(3)

    if share_name.lower() in SKIP:
        return m.group(0)

    # Lê grupo do valid_users (primeiro @grupo)
    vu = re.search(r'^\s*valid users\s*=\s*@(\S+)', body, re.MULTILINE)
    if not vu:
        return m.group(0)
    correct_grp = vu.group(1)

    # Verifica se já tem force group
    fg = re.search(r'^\s*force group\s*=\s*(\S+)', body, re.MULTILINE)
    if fg:
        current_grp = fg.group(1).lstrip('+')
        if current_grp == correct_grp:
            print(f'  OK: [{share_name}] force group = {correct_grp}')
            return m.group(0)
        # Corrige
        print(f'  [{share_name}]: {current_grp} → {correct_grp}')
        new_body = re.sub(
            r'(^\s*force group\s*=\s*)(\S+)',
            r'\g<1>' + correct_grp,
            body,
            flags=re.MULTILINE
        )
        return header + new_body
    else:
        # Adiciona force group após force directory mode
        print(f'  [{share_name}]: adicionando force group = {correct_grp}')
        new_body = re.sub(
            r'(force directory mode\s*=\s*\S+)',
            r'\1\n    force group          = ' + correct_grp,
            body, count=1
        )
        return header + new_body

result = re.sub(
    r'(\[([^\]]+)\]\n)(.*?)(?=\[|\Z)',
    fix_section,
    content,
    flags=re.DOTALL
)

with open(conf_path, 'w') as f:
    f.write(result)

print('\nsmb.conf atualizado.')
PYEOF

echo ""
echo "==> Validando smb.conf..."
testparm -s /etc/samba/smb.conf > /dev/null && echo "    OK: testparm passou"

echo "==> Corrigindo ownership das pastas para o grupo correto..."
python3 << 'PYEOF'
import re, os, subprocess, grp as grpmod

conf_path = '/etc/samba/smb.conf'
with open(conf_path) as f:
    content = f.read()

SKIP = {'global', 'recycle', 'homes', 'printers'}

for m in re.finditer(r'\[([^\]]+)\]\s*\n(.*?)(?=\[|\Z)', content, re.DOTALL):
    share_name = m.group(1).strip()
    body       = m.group(2)
    if share_name.lower() in SKIP:
        continue

    fg = re.search(r'^\s*force group\s*=\s*(\S+)', body, re.MULTILINE)
    if not fg:
        continue
    grp = fg.group(1).lstrip('+')

    pm = re.search(r'^\s*path\s*=\s*(.+)', body, re.MULTILINE)
    if not pm:
        continue
    path = pm.group(1).strip()
    if not os.path.isdir(path):
        continue

    try:
        grpmod.getgrnam(grp)
    except KeyError:
        print(f'  AVISO: grupo {grp} nao existe — pulando {share_name}')
        continue

    print(f'  {share_name}: chown -R :{grp} {path}')
    subprocess.run(['chown', '-R', f':{grp}', path])
    subprocess.run(['find', path, '-type', 'f', '-exec', 'chmod', 'g+rw', '{}', '+'])
    subprocess.run(['find', path, '-type', 'd', '-exec', 'chmod', 'g+rwx', '{}', '+'])

print('Concluído.')
PYEOF

echo ""
echo "==> Reiniciando smbd..."
systemctl restart smbd
systemctl is-active smbd && echo "    OK: smbd ativo"
echo ""
echo "Fix concluído. Verifique com:"
echo "  grep 'force group' /etc/samba/smb.conf"
