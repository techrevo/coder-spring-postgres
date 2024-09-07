terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

locals {
  username = data.coder_workspace_owner.me.name
}

data "coder_provisioner" "me" {}

provider "docker" {}

data "coder_workspace" "me" {}

data "coder_workspace_owner" "me" {}

data "coder_parameter" "app_name" {
  name        = "Application name"
  description = "Name of the application (es. springboot)"
  mutable     = false
}

data "coder_parameter" "org_id" {
  name        = "Organization ID"
  description = "Identifier of the organization (es. com.example)"
  mutable     = false
}

data "coder_parameter" "builder_type" {
  name        = "Gradle or Maven?"
  description = "Choose your favorite builder"
  type        = "string"
  default     = "gradle-project"

  option {
    name  = "Gradle"
    value = "gradle-project"
  }

  option {
    name  = "Maven"
    value = "maven-project"
  }
}

data "coder_parameter" "db_pass" {
  name        = "Database password"
  description = "Password of the PostgreSQL database"
  mutable     = false
}

resource "coder_agent" "main" {
  arch           = data.coder_provisioner.me.arch
  os             = "linux"
  startup_script = <<-EOT
    set -e

    # Prepare user home with default files on first start.
    if [ ! -f ~/.init_done ]; then
      cp -rT /etc/skel ~
      touch ~/.init_done
    fi

    # Install the latest code-server.
    # Append "--version x.x.x" to install a specific version of code-server.
    curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/tmp/code-server

    # Start code-server in the background.
    /tmp/code-server/bin/code-server --auth none --port 13337 >/tmp/code-server.log 2>&1 &

    # Install extensions
    /tmp/code-server/bin/code-server --install-extension redhat.java
    /tmp/code-server/bin/code-server --install-extension vmware.vscode-spring-boot
    /tmp/code-server/bin/code-server --install-extension cweijan.vscode-database-client2
  EOT

  # These environment variables allow you to make Git commits right away after creating a
  # workspace. Note that they take precedence over configuration defined in ~/.gitconfig!
  # You can remove this block if you'd prefer to configure Git manually or using
  # dotfiles. (see docs/dotfiles.md)
  env = {
    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = "${data.coder_workspace_owner.me.email}"
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = "${data.coder_workspace_owner.me.email}"
  }

  # The following metadata blocks are optional. They are used to display
  # information about your workspace in the dashboard. You can remove them
  # if you don't want to display any information.
  # For basic resources, you can use the `coder stat` command.
  # If you need more control, you can write your own script.
  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "3_home_disk"
    script       = "coder stat disk --path $${HOME}"
    interval     = 60
    timeout      = 1
  }

  metadata {
    display_name = "CPU Usage (Host)"
    key          = "4_cpu_usage_host"
    script       = "coder stat cpu --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Memory Usage (Host)"
    key          = "5_mem_usage_host"
    script       = "coder stat mem --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Load Average (Host)"
    key          = "6_load_host"
    # get load avg scaled by number of cores
    script   = <<EOT
      echo "`cat /proc/loadavg | awk '{ print $1 }'` `nproc`" | awk '{ printf "%0.2f", $1/$2 }'
    EOT
    interval = 60
    timeout  = 1
  }

  metadata {
    display_name = "Swap Usage (Host)"
    key          = "7_swap_host"
    script       = <<EOT
      free -b | awk '/^Swap/ { printf("%.1f/%.1f", $3/1024.0/1024.0/1024.0, $2/1024.0/1024.0/1024.0) }'
    EOT
    interval     = 10
    timeout      = 1
  }
}

resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "VS Code Server"
  url          = "http://localhost:13337/?folder=/home/${local.username}/${data.coder_parameter.app_name.value}"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 5
    threshold = 6
  }
}

resource "coder_app" "app" {
  agent_id     = coder_agent.main.id
  slug         = "app"
  display_name = "Web App"
  url          = "http://localhost:8080"
  icon         = "https://cdn-icons-png.flaticon.com/512/8654/8654198.png"
  subdomain    = true
}

resource "docker_network" "default" {
  name   = lower(data.coder_workspace.me.name)
  driver = "bridge"
}

resource "docker_volume" "home_volume" {
  name = "${lower(data.coder_workspace.me.name)}-main"
  # Protect the volume from being deleted due to changes in attributes.
  lifecycle {
    ignore_changes = all
  }
  # Add labels in Docker to keep track of orphan resources.
  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  # This field becomes outdated if the workspace is renamed but can
  # be useful for debugging or cleaning out dangling volumes.
  labels {
    label = "coder.workspace_name_at_creation"
    value = data.coder_workspace.me.name
  }
}

resource "docker_volume" "db_volume" {
  name = "${lower(data.coder_workspace.me.name)}-db"
  # Protect the volume from being deleted due to changes in attributes.
  lifecycle {
    ignore_changes = all
  }
  # Add labels in Docker to keep track of orphan resources.
  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  # This field becomes outdated if the workspace is renamed but can
  # be useful for debugging or cleaning out dangling volumes.
  labels {
    label = "coder.workspace_name_at_creation"
    value = data.coder_workspace.me.name
  }
}

resource "docker_image" "main" {
  name = lower(data.coder_workspace.me.name)
  build {
    context = "./build"
    build_args = {
      USER = local.username
      APP_NAME = data.coder_parameter.app_name.value
      ORGANIZATION_ID = data.coder_parameter.org_id.value
      BUILDER_TYPE = data.coder_parameter.builder_type.value
      DATABASE_HOST = "${lower(data.coder_workspace.me.name)}-db"
      DATABASE_PASS = data.coder_parameter.db_pass.value
    }
  }
  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(path.module, "build/*") : filesha1(f)]))
  }
}

resource "docker_image" "db" {
  name = "postgres:latest"
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = docker_image.main.name
  # Uses lower() to avoid Docker restriction on container names.
  name = lower(data.coder_workspace.me.name)
  # Hostname makes the shell more user friendly: coder@my-workspace:~$
  hostname = lower(data.coder_workspace.me.name)
  # Use the docker gateway if the access URL is 127.0.0.1
  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
  env        = ["CODER_AGENT_TOKEN=${coder_agent.main.token}"]
  ports {
    internal = 8080
    external = 8080
  }
  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }
  volumes {
    container_path = "/home/${local.username}"
    volume_name    = docker_volume.home_volume.name
    read_only      = false
  }
  networks_advanced {
    name = docker_network.default.name
  }

  # Add labels in Docker to keep track of orphan resources.
  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name"
    value = data.coder_workspace.me.name
  }
}

resource "docker_container" "db" {
  count = data.coder_workspace.me.start_count
  image = docker_image.db.name
  # Uses lower() to avoid Docker restriction on container names.
  name = "${lower(data.coder_workspace.me.name)}-db"
  # Hostname makes the shell more user friendly: coder@my-workspace:~$
  hostname = "${lower(data.coder_workspace.me.name)}-db"
  env      = ["CODER_AGENT_TOKEN=${coder_agent.main.token}", "POSTGRES_DB=${lower(data.coder_parameter.app_name.value)}", "POSTGRES_USER=${data.coder_workspace_owner.me.name}", "POSTGRES_PASSWORD=${data.coder_parameter.db_pass.value}"]

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }
  volumes {
    container_path = "/var/lib/postgresql"
    volume_name    = docker_volume.db_volume.name
    read_only      = false
  }
  networks_advanced {
    name = docker_network.default.name
  }

  # Add labels in Docker to keep track of orphan resources.
  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name"
    value = data.coder_workspace.me.name
  }
}
