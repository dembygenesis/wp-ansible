# ===========================================
# Global Variables
# ===========================================

variable "ssh_host" {
  description = "SSH host alias or IP"
  type        = string
}

variable "ssh_user" {
  description = "SSH user for remote commands"
  type        = string
  default     = "root"
}

variable "ssl_email" {
  description = "Email for Let's Encrypt certificates"
  type        = string
}

variable "nginx_sites_available" {
  description = "Path to nginx sites-available"
  type        = string
  default     = "/etc/nginx/sites-available"
}

variable "nginx_sites_enabled" {
  description = "Path to nginx sites-enabled"
  type        = string
  default     = "/etc/nginx/sites-enabled"
}

# ===========================================
# Sites Configuration
# ===========================================

variable "sites" {
  description = "Map of WordPress sites to deploy"
  type = map(object({
    domain             = string
    wp_port            = number
    mysql_port         = number
    wp_db_name         = string
    wp_db_user         = string
    wp_db_password     = string
    mysql_root_password = string
    enabled            = optional(bool, true)
  }))
}
