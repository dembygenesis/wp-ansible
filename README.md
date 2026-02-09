# wp-ansible

Deploy WordPress to any VPS with one command. Tear it down with another.

```
ansible-playbook playbooks/setup.yml     # Deploy
ansible-playbook playbooks/teardown.yml  # Destroy
```

**Creates:** Docker containers (WordPress + MySQL) + Nginx reverse proxy + Let's Encrypt SSL + WordPress admin user + Theme installed.

---

## Quick Start

```bash
# 1. Clone
git clone git@github.com:dembygenesis/wp-ansible.git
cd wp-ansible

# 2. Install Ansible
pip install ansible
ansible-galaxy collection install community.docker

# 3. Configure
cp config.yml.example config.yml
vim config.yml  # Edit with your values

# 4. Set server connection (see "Server Connection" section)

# 5. Deploy
ansible-playbook playbooks/setup.yml
```

Your site is live at `https://your-domain.com`

---

## Server Connection

### Option A: Environment Variables (recommended for automation)

```bash
export WP_SERVER_HOST="your-server-ip-or-hostname"
export WP_SERVER_USER="root"
export WP_SSH_KEY="~/.ssh/id_rsa"

ansible-playbook playbooks/setup.yml
```

### Option B: SSH Config (recommended for personal use)

Add to `~/.ssh/config`:

```
Host myserver
    HostName 123.45.67.89
    User root
    IdentityFile ~/.ssh/id_rsa
```

Then edit `inventory.yml`:

```yaml
all:
  hosts:
    wordpress_server:
      ansible_host: myserver
```

### Option C: Direct inventory edit

Edit `inventory.yml` directly with your server details.

---

## Configuration

All settings live in `config.yml`. Copy from example and customize:

```yaml
# Domain & SSL
domain: myblog.com
ssl_email: admin@myblog.com

# WordPress Admin (created on first deploy)
wp_admin_user: admin
wp_admin_password: your-secure-password
wp_admin_email: admin@myblog.com
wp_site_title: My Blog

# Theme (wordpress.org slug)
wp_theme: flavor-flavor

# Database
wp_db_name: wordpress
wp_db_user: wp_user
wp_db_password: db-password-here
mysql_root_password: root-password-here

# Ports
wp_port: 3006
mysql_port: 3307
```

---

## Commands

| Command | What it does |
|---------|--------------|
| `ansible-playbook playbooks/setup.yml` | Full deploy |
| `ansible-playbook playbooks/teardown.yml` | Full teardown |
| `ansible-playbook playbooks/setup.yml --check` | Dry run (no changes) |
| `ansible-playbook playbooks/setup.yml --tags nginx` | Only nginx/SSL |
| `ansible-playbook playbooks/setup.yml --tags wordpress` | Only WordPress |

### Tags available
- `common` - Base packages
- `docker` - Docker installation
- `nginx` - Nginx + SSL
- `wordpress` - WordPress + theme

---

## Operationalizing Secrets

**DO NOT commit `config.yml` with real passwords.** Here's how to handle secrets properly:

### For Personal/Dev Use

1. Keep `config.yml` git-ignored (already in `.gitignore`)
2. Store passwords in a password manager
3. Copy from `config.yml.example` on each machine

### For Team/CI Use: Environment Variables

```yaml
# config.yml - use env vars for secrets
wp_admin_password: "{{ lookup('env', 'WP_ADMIN_PASSWORD') }}"
wp_db_password: "{{ lookup('env', 'WP_DB_PASSWORD') }}"
mysql_root_password: "{{ lookup('env', 'MYSQL_ROOT_PASSWORD') }}"
```

```bash
# In CI or .bashrc (not committed)
export WP_ADMIN_PASSWORD="super-secret"
export WP_DB_PASSWORD="also-secret"
export MYSQL_ROOT_PASSWORD="very-secret"

ansible-playbook playbooks/setup.yml
```

### For Production: Ansible Vault

```bash
# 1. Create encrypted secrets file
ansible-vault create secrets.yml

# 2. Add your secrets
wp_admin_password: super-secret
wp_db_password: also-secret
mysql_root_password: very-secret

# 3. Reference in config.yml
wp_admin_password: "{{ wp_admin_password }}"

# 4. Run with vault password
ansible-playbook playbooks/setup.yml --ask-vault-pass

# Or with password file (for CI)
ansible-playbook playbooks/setup.yml --vault-password-file ~/.vault_pass
```

### Secret Rotation

```bash
# 1. Update secrets in config.yml or vault
# 2. Re-run playbook - it will update WordPress
ansible-playbook playbooks/setup.yml --tags wordpress
```

---

## Server Prerequisites

The playbook installs most things, but your server needs:

- Ubuntu 20.04+ (or Debian-based)
- SSH access (key-based recommended)
- Root or sudo access
- Ports 80, 443 open
- DNS pointing to server IP

### First-time server setup

```bash
# On server
apt update && apt upgrade -y
# That's it - Ansible handles the rest
```

---

## Troubleshooting

**"SSL cert failed"**
> DNS not pointing to server yet. Wait for propagation, retry.

**"502 Bad Gateway"**
> Containers still starting. Wait 30s. Check: `docker logs wp_wordpress`

**"Connection refused"**
> Check SSH config. Test with: `ssh wordpress_server`

**"Permission denied"**
> Ensure SSH key is correct. Check `ansible_user` is root or has sudo.

**Want to start fresh?**
```bash
ansible-playbook playbooks/teardown.yml
ansible-playbook playbooks/setup.yml
```

---

## File Structure

```
wp-ansible/
├── ansible.cfg           # Ansible settings
├── inventory.yml         # Server connection
├── config.yml.example    # Template config
├── config.yml            # YOUR CONFIG (git-ignored)
├── playbooks/
│   ├── setup.yml         # Deploy everything
│   └── teardown.yml      # Remove everything
└── roles/
    ├── common/           # Base packages
    ├── docker/           # Docker installation
    ├── nginx/            # Nginx + SSL
    └── wordpress/        # WordPress + WP-CLI
```

---

## Why Ansible?

| Tool | Best for |
|------|----------|
| Terraform | Creating/destroying cloud VMs |
| **Ansible** | **Configuring existing servers** |
| Docker | Running applications |

Ansible is THE tool for VPS configuration. Terraform is overkill if your server already exists.
