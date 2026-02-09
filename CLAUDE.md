# wp-ansible

Ansible playbooks for deploying WordPress to any VPS.

## Quick Reference

```bash
# Deploy
ansible-playbook playbooks/setup.yml -e @recipes/mysite.yml

# Teardown
ansible-playbook playbooks/teardown.yml -e @recipes/mysite.yml

# Dry run
ansible-playbook playbooks/setup.yml -e @recipes/mysite.yml --check
```

## Recipes

Check `recipes/` folder for existing site configs:
- `recipes/*.example.yml` - Example templates (committed)
- `recipes/*.yml` - Your actual configs (gitignored)

### Using a recipe

```bash
# Copy an example
cp recipes/blog.example.yml recipes/mysite.yml

# Edit with your values
vim recipes/mysite.yml

# Deploy using recipe
ansible-playbook playbooks/setup.yml -e @recipes/mysite.yml
```

### Multi-site

Run multiple WordPress sites on same server - just use different:
- `wp_port` / `mysql_port`
- `container_prefix`
- `deploy_path`

## Key Files

| File | Purpose |
|------|---------|
| `playbooks/setup.yml` | Deploy WordPress |
| `playbooks/teardown.yml` | Destroy WordPress |
| `config.yml.example` | Default config template |
| `recipes/*.example.yml` | Site-specific examples |
| `inventory.yml` | Server connection |

## Tags

```bash
--tags common     # Base packages only
--tags docker     # Docker only
--tags nginx      # NGINX + SSL only
--tags wordpress  # WordPress only
```
