#!/bin/bash
# Aplica correções em servidores instalados antes dos fixes do git
set -e

if [[ $EUID -ne 0 ]]; then
    echo "Execute como root: sudo bash fix_server.sh"
    exit 1
fi

echo "==> Criando wrapper de senha..."
cat > /usr/local/bin/cdpni-setpass << 'EOF'
#!/bin/bash
user="$1"
pass="$2"
hash=$(openssl passwd -6 "$pass")
sed -i "s|^${user}:[^:]*:|${user}:${hash}:|" /etc/shadow
EOF
chmod 700 /usr/local/bin/cdpni-setpass
echo "    OK: /usr/local/bin/cdpni-setpass"

echo "==> Criando wrapper de membros de grupo..."
cat > /usr/local/bin/cdpni-setgroup << 'PYEOF'
#!/usr/bin/env python3
import sys

group   = sys.argv[1]
members = sys.argv[2] if len(sys.argv) > 2 else ''

for path in ('/etc/group', '/etc/gshadow'):
    try:
        with open(path) as f:
            lines = f.readlines()
        out = []
        for line in lines:
            parts = line.rstrip('\n').split(':')
            if parts[0] == group:
                parts[-1] = members
                line = ':'.join(parts) + '\n'
            out.append(line)
        with open(path, 'w') as f:
            f.writelines(out)
    except FileNotFoundError:
        pass
PYEOF
chmod 700 /usr/local/bin/cdpni-setgroup
echo "    OK: /usr/local/bin/cdpni-setgroup"

echo "==> Criando wrapper de criação de usuário..."
cat > /usr/local/bin/cdpni-useradd << 'PYEOF'
#!/usr/bin/env python3
# Uso: cdpni-useradd <username>
import sys, os, re, shutil, subprocess

username = sys.argv[1]

if not re.match(r'^[a-z][a-z0-9_-]{0,31}$', username):
    print(f'Nome inválido: {username}', file=sys.stderr)
    sys.exit(1)

with open('/etc/passwd') as f:
    for line in f:
        if line.split(':')[0] == username:
            print(f'Usuário já existe: {username}', file=sys.stderr)
            sys.exit(1)

uids = set()
with open('/etc/passwd') as f:
    for line in f:
        parts = line.split(':')
        try:
            uids.add(int(parts[2]))
        except (IndexError, ValueError):
            pass
uid = max((u for u in uids if 1000 <= u < 60000), default=999) + 1
home = f'/home/{username}'

with open('/etc/passwd', 'a') as f:
    f.write(f'{username}:x:{uid}:{uid}::{home}:/bin/bash\n')
with open('/etc/shadow', 'a') as f:
    f.write(f'{username}:!::0:99999:7:::\n')
with open('/etc/group', 'a') as f:
    f.write(f'{username}:x:{uid}:\n')
try:
    with open('/etc/gshadow', 'a') as f:
        f.write(f'{username}:!::\n')
except FileNotFoundError:
    pass

subprocess.run(['mkdir', '-p', '-m', '755', home], check=True)
subprocess.run(['chown', f'{uid}:{uid}', home], check=True)
skel = '/etc/skel'
if os.path.isdir(skel):
    for item in os.listdir(skel):
        src = os.path.join(skel, item)
        dst = os.path.join(home, item)
        if os.path.isfile(src):
            shutil.copy2(src, dst)
            subprocess.run(['chown', f'{uid}:{uid}', dst])

print(f'Usuário {username} criado com uid={uid}')
PYEOF
chmod 700 /usr/local/bin/cdpni-useradd
echo "    OK: /usr/local/bin/cdpni-useradd"

echo "==> Atualizando sudoers..."
cat > /etc/sudoers.d/cdpni-portal << 'EOF'
Defaults:cdpni !log_allowed, !syslog
cdpni ALL=(root) NOPASSWD: /usr/local/bin/cdpni-setpass, /usr/local/bin/cdpni-setgroup, /usr/local/bin/cdpni-useradd, /usr/bin/smbpasswd, /usr/sbin/useradd, /usr/sbin/userdel, /usr/sbin/usermod, /usr/sbin/groupadd, /usr/sbin/groupdel, /usr/bin/gpasswd, /usr/bin/tee, /bin/tee, /usr/bin/systemctl, /usr/bin/smbstatus, /usr/bin/smbcontrol, /usr/bin/testparm, /usr/bin/smartctl, /bin/mkdir, /bin/chmod, /bin/chown, /bin/tar, /usr/bin/tar, /usr/bin/tail, /usr/bin/setfacl, /usr/bin/getfacl, /bin/mv, /usr/bin/mv, /bin/rm, /usr/bin/rm, /bin/bash
EOF
chmod 440 /etc/sudoers.d/cdpni-portal
visudo -cf /etc/sudoers.d/cdpni-portal && echo "    OK: /etc/sudoers.d/cdpni-portal"

echo "==> Adicionando cdpni ao grupo adm (acesso a logs)..."
usermod -aG adm cdpni
echo "    OK: cdpni no grupo adm"

echo "==> Atualizando repositório..."
cd /opt/smb && git pull

echo "==> Atualizando app.py..."
cp /opt/smb/roles/flask_portal/files/app.py /opt/cdpni-portal/app.py
chown cdpni:cdpni /opt/cdpni-portal/app.py

echo "==> Reiniciando portal..."
systemctl restart cdpni-portal
systemctl is-active cdpni-portal && echo "    OK: cdpni-portal ativo"

echo ""
echo "Fix aplicado com sucesso."
