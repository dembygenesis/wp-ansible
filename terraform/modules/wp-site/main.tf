# ===========================================
# WordPress Site Module
# ===========================================

locals {
  container_prefix = var.site_name
  remote_dir       = "/opt/wp-deployments/${var.site_name}"
  nginx_conf_name  = "${replace(var.domain, ".", "-")}.conf"

  # Docker compose content
  docker_compose = <<-EOF
    version: '3.8'

    services:
      wordpress:
        image: wordpress:latest
        container_name: ${local.container_prefix}_wordpress
        restart: unless-stopped
        ports:
          - "${var.wp_port}:80"
        environment:
          WORDPRESS_DB_HOST: ${local.container_prefix}_mysql:3306
          WORDPRESS_DB_NAME: ${var.wp_db_name}
          WORDPRESS_DB_USER: ${var.wp_db_user}
          WORDPRESS_DB_PASSWORD: ${var.wp_db_password}
        volumes:
          - wordpress_data:/var/www/html
        depends_on:
          mysql:
            condition: service_healthy
        networks:
          - wp_network

      mysql:
        image: mysql:8.0
        container_name: ${local.container_prefix}_mysql
        restart: unless-stopped
        ports:
          - "${var.mysql_port}:3306"
        environment:
          MYSQL_ROOT_PASSWORD: ${var.mysql_root_password}
          MYSQL_DATABASE: ${var.wp_db_name}
          MYSQL_USER: ${var.wp_db_user}
          MYSQL_PASSWORD: ${var.wp_db_password}
        volumes:
          - mysql_data:/var/lib/mysql
        healthcheck:
          test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${var.mysql_root_password}"]
          interval: 10s
          timeout: 5s
          retries: 5
        networks:
          - wp_network

    volumes:
      wordpress_data:
        name: ${local.container_prefix}_wordpress_data
      mysql_data:
        name: ${local.container_prefix}_mysql_data

    networks:
      wp_network:
        name: ${local.container_prefix}_network
  EOF

  # Nginx config
  nginx_conf = <<-EOF
    server {
        server_name ${var.domain};

        location / {
            proxy_http_version 1.1;
            proxy_set_header X-Forwarded-For $remote_addr;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header Host $http_host;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header Connection '';
            proxy_buffering off;
            proxy_request_buffering off;
            proxy_pass http://127.0.0.1:${var.wp_port}/;
        }

        listen 80;
    }
  EOF
}

# ===========================================
# Create remote directory & deploy compose
# ===========================================

resource "null_resource" "deploy" {
  triggers = {
    domain      = var.domain
    wp_port     = var.wp_port
    mysql_port  = var.mysql_port
    site_name   = var.site_name
  }

  provisioner "local-exec" {
    command = <<-CMD
      ssh ${var.ssh_host} "mkdir -p ${local.remote_dir}"
    CMD
  }

  provisioner "local-exec" {
    command = <<-CMD
      echo '${local.docker_compose}' | ssh ${var.ssh_host} "cat > ${local.remote_dir}/docker-compose.yml"
    CMD
  }
}

# ===========================================
# Setup Nginx
# ===========================================

resource "null_resource" "nginx" {
  depends_on = [null_resource.deploy]

  triggers = {
    domain   = var.domain
    wp_port  = var.wp_port
  }

  provisioner "local-exec" {
    command = <<-CMD
      echo '${local.nginx_conf}' | ssh ${var.ssh_host} "sudo tee ${var.nginx_sites_available}/${local.nginx_conf_name} > /dev/null"
      ssh ${var.ssh_host} "sudo ln -sf ${var.nginx_sites_available}/${local.nginx_conf_name} ${var.nginx_sites_enabled}/"
      ssh ${var.ssh_host} "sudo nginx -t && sudo systemctl reload nginx"
    CMD
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-CMD
      ssh ${self.triggers.ssh_host} "sudo rm -f ${self.triggers.nginx_sites_enabled}/${self.triggers.nginx_conf_name} ${self.triggers.nginx_sites_available}/${self.triggers.nginx_conf_name} || true"
      ssh ${self.triggers.ssh_host} "sudo nginx -t && sudo systemctl reload nginx || true"
    CMD
    environment = {
      # These need to be captured in triggers for destroy
    }
    on_failure = continue
  }

  lifecycle {
    # Store values needed for destroy
    replace_triggered_by = [null_resource.deploy]
  }
}

# ===========================================
# SSL Certificate
# ===========================================

resource "null_resource" "ssl" {
  depends_on = [null_resource.nginx]

  triggers = {
    domain = var.domain
  }

  provisioner "local-exec" {
    command = <<-CMD
      CERT_EXISTS=$(ssh ${var.ssh_host} "sudo test -f /etc/letsencrypt/live/${var.domain}/fullchain.pem && echo 'yes' || echo 'no'")
      if [ "$CERT_EXISTS" = "no" ]; then
        ssh ${var.ssh_host} "sudo certbot --nginx -d ${var.domain} --non-interactive --agree-tos --email ${var.ssl_email}"
      else
        echo "SSL cert already exists for ${var.domain}"
      fi
    CMD
  }
}

# ===========================================
# Start Containers
# ===========================================

resource "null_resource" "containers" {
  depends_on = [null_resource.ssl]

  triggers = {
    site_name  = var.site_name
    remote_dir = local.remote_dir
    ssh_host   = var.ssh_host
  }

  provisioner "local-exec" {
    command = <<-CMD
      ssh ${var.ssh_host} "cd ${local.remote_dir} && docker compose up -d"
    CMD
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-CMD
      ssh ${self.triggers.ssh_host} "cd ${self.triggers.remote_dir} && docker compose down -v || true"
      ssh ${self.triggers.ssh_host} "rm -rf ${self.triggers.remote_dir} || true"
    CMD
    on_failure = continue
  }
}

# ===========================================
# Outputs
# ===========================================

output "site_url" {
  description = "URL of the deployed site"
  value       = "https://${var.domain}"
}

output "container_prefix" {
  description = "Container prefix for this site"
  value       = local.container_prefix
}
