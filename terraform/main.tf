# ===========================================
# WordPress Multi-Site Deployment
# ===========================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

# ===========================================
# Deploy each enabled site
# ===========================================

module "wp_site" {
  for_each = { for k, v in var.sites : k => v if v.enabled }

  source = "./modules/wp-site"

  site_name            = each.key
  domain               = each.value.domain
  wp_port              = each.value.wp_port
  mysql_port           = each.value.mysql_port
  wp_db_name           = each.value.wp_db_name
  wp_db_user           = each.value.wp_db_user
  wp_db_password       = each.value.wp_db_password
  mysql_root_password  = each.value.mysql_root_password

  ssh_host             = var.ssh_host
  ssh_user             = var.ssh_user
  ssl_email            = var.ssl_email
  nginx_sites_available = var.nginx_sites_available
  nginx_sites_enabled  = var.nginx_sites_enabled
}

# ===========================================
# Outputs
# ===========================================

output "deployed_sites" {
  description = "URLs of deployed WordPress sites"
  value = {
    for k, v in module.wp_site : k => v.site_url
  }
}
