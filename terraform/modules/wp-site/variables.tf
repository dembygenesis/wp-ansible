variable "site_name" {
  description = "Unique identifier for this site (used for container prefix)"
  type        = string
}

variable "domain" {
  description = "Domain name for this WordPress site"
  type        = string
}

variable "wp_port" {
  description = "Port for WordPress container"
  type        = number
}

variable "mysql_port" {
  description = "Port for MySQL container"
  type        = number
}

variable "wp_db_name" {
  description = "WordPress database name"
  type        = string
}

variable "wp_db_user" {
  description = "WordPress database user"
  type        = string
}

variable "wp_db_password" {
  description = "WordPress database password"
  type        = string
  sensitive   = true
}

variable "mysql_root_password" {
  description = "MySQL root password"
  type        = string
  sensitive   = true
}

variable "ssh_host" {
  description = "SSH host for deployment"
  type        = string
}

variable "ssh_user" {
  description = "SSH user"
  type        = string
}

variable "ssl_email" {
  description = "Email for SSL certificate"
  type        = string
}

variable "nginx_sites_available" {
  description = "Nginx sites-available path"
  type        = string
}

variable "nginx_sites_enabled" {
  description = "Nginx sites-enabled path"
  type        = string
}
