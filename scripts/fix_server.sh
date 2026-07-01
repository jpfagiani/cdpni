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

echo "==> Atualizando sudoers..."
cat > /etc/sudoers.d/cdpni-portal << 'EOF'
Defaults:cdpni !log_allowed, !syslog
cdpni ALL=(root) NOPASSWD: /usr/local/bin/cdpni-setpass, /usr/local/bin/cdpni-setgroup, /usr/bin/smbpasswd, /usr/sbin/useradd, /usr/sbin/userdel, /usr/sbin/usermod, /usr/sbin/groupadd, /usr/sbin/groupdel, /usr/bin/gpasswd, /usr/bin/tee, /bin/tee, /usr/bin/systemctl, /usr/bin/smbstatus, /usr/bin/smbcontrol, /usr/bin/testparm, /usr/bin/smartctl, /bin/mkdir, /bin/chmod, /bin/chown, /bin/tar, /usr/bin/tar, /usr/bin/tail, /usr/bin/setfacl, /usr/bin/getfacl, /bin/bash
EOF
chmod 440 /etc/sudoers.d/cdpni-portal
visudo -cf /etc/sudoers.d/cdpni-portal && echo "    OK: /etc/sudoers.d/cdpni-portal"

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
