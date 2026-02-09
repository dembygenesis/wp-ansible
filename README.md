# wp-terraform

Deploy WordPress sites with one command. Tear them down with another.

## What This Does

```
You define sites in a config file → Terraform creates everything → WordPress runs on HTTPS
```

**Creates:**
- Docker containers (WordPress + MySQL)
- Nginx reverse proxy config
- Let's Encrypt SSL cert (auto-renewed)

**Per site. As many sites as you want.**

---

## Quick Start

```bash
# 1. Clone
git clone git@github.com:dembygenesis/wp-terraform.git
cd wp-terraform/terraform

# 2. Config
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your sites

# 3. Deploy
terraform init    # First time only
terraform apply   # Creates everything
```

That's it. Your site is live at `https://your-domain.com`

---

## The Config File

`terraform/terraform.tfvars` - this is where you define your sites:

```hcl
ssh_host  = "eufit"              # Your SSH alias or IP
ssl_email = "you@email.com"      # For Let's Encrypt

sites = {
  # Each block = one WordPress site
  "my-blog" = {
    domain              = "blog.example.com"
    wp_port             = 3006        # Pick unique ports
    mysql_port          = 3007        # per site
    wp_db_name          = "wordpress"
    wp_db_user          = "wp_user"
    wp_db_password      = "secure-password-here"
    mysql_root_password = "another-secure-password"
    enabled             = true        # false = skip this site
  }

  # Add more sites...
  "client-site" = {
    domain              = "client.example.com"
    wp_port             = 3008
    mysql_port          = 3009
    # ...
  }
}
```

---

## Commands You'll Use

| Command | What it does |
|---------|--------------|
| `terraform init` | Downloads dependencies (run once) |
| `terraform plan` | Preview what will happen |
| `terraform apply` | Create/update everything |
| `terraform destroy` | Tear down everything |

### Day-to-day workflow

```bash
# Add a new site
vim terraform.tfvars  # Add new site block
terraform apply       # Creates just the new site

# Remove a site
vim terraform.tfvars  # Set enabled = false (or delete block)
terraform apply       # Removes just that site

# Update a site (change port, etc)
vim terraform.tfvars  # Change values
terraform apply       # Recreates affected resources

# Nuke everything
terraform destroy     # Gone. All of it.
```

---

## Terraform for Backend Devs

**Think of it like this:**

| Terraform | Backend Equivalent |
|-----------|-------------------|
| `.tf` files | Schema/migrations |
| `terraform.tfvars` | `.env` file |
| `terraform apply` | `db:migrate` |
| `terraform destroy` | `db:rollback` |
| State file | Migration history |

**Key concepts:**

1. **Declarative** - You describe what you want, not how to do it
2. **Idempotent** - Run `apply` 100 times, same result
3. **State** - Terraform tracks what it created (in `terraform.tfstate`)

**The flow:**
```
Your config (tfvars)
    ↓ terraform plan
Shows diff (what will change)
    ↓ terraform apply
Makes it real
    ↓
State file updated
```

---

## File Structure

```
wp-terraform/
├── terraform/
│   ├── main.tf              # "Deploy all sites in the config"
│   ├── variables.tf         # Input definitions
│   ├── terraform.tfvars     # YOUR CONFIG (git-ignored)
│   └── modules/wp-site/     # The actual logic
│       ├── main.tf          # Docker + Nginx + SSL setup
│       └── variables.tf     # Per-site inputs
│
├── setup.sh                 # Non-terraform alternative
└── teardown.sh              # Non-terraform alternative
```

---

## Prerequisites

**On your machine:**
```bash
brew install terraform   # or: apt install terraform
```

**On the server:**
- Docker + Docker Compose
- Nginx
- Certbot (`apt install certbot python3-certbot-nginx`)
- SSH access configured (`~/.ssh/config`)

**DNS:**
- Point your domain to the server IP before deploying

---

## Troubleshooting

**"SSL cert failed"**
→ DNS not pointing to server yet. Wait for propagation, retry.

**"502 Bad Gateway"**
→ Containers still starting. Wait 30s. Check: `docker logs <prefix>_wordpress`

**"Port already in use"**
→ Pick different ports in config.

**"State is locked"**
→ Someone else running terraform, or crashed. Run: `terraform force-unlock <lock-id>`

**Want to start fresh?**
```bash
rm terraform.tfstate*   # Forget everything
terraform apply         # Recreate from scratch
```

---

## Non-Terraform Option

Don't want Terraform? Use the bash scripts:

```bash
cp config.env.example config.env
vim config.env
./setup.sh      # Deploy
./teardown.sh   # Destroy
```

Single site only. No state tracking. But works.
