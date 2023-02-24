<<EOT
      export DEBIAN_FRONTEND=noninteractive 
      sudo apt update && sudo apt -y upgrade
      if ! which psql; then
        sudo sh -c 'echo 'deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main' > /etc/apt/sources.list.d/pgdg.list'
        wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - 
        sudo apt-get update; sudo apt install -y postgresql-14 postgresql-client-14 figlet;
      fi
      [ -d /dumps ] || mkdir /dumps && chown -R postgres:postgres /dumps
      cd /dumps
      gsutil cp gs://${google_storage_bucket.dumps.name}/${var.databases.each.script_name}.sql .
      chown postgres:postgres ${var.databases.each.script_name}.sql
      PGPASSWORD=${var.databases.each.dbpass} pg_dump -h ${var.databases.each.dbhost} -U ${var.databases.each.username} -O ${var.databases.each.dbname} ${var.databases.each.exclude_tables} > ${var.databases.each.dbname}.sql
      chown postgres:postgres ${var.databases.each.dbname}.sql
      su -c 'createdb ${var.databases.each.dbname}' postgres
      su -c 'psql ${var.databases.each.dbname} < ${var.databases.each.dbname}.sql' postgres
      su -c 'psql ${var.databases.each.dbname} < ${var.databases.each.script_name}.sql' postgres
      su -c 'pg_dump -O -Z 9 ${var.databases.each.dbname} > anonymized-dump.sql.gz' postgres
      gsutil cp anonymized-dump.sql.gz gs://${google_storage_bucket.dumps.name}
      su -c 'dropdb ${var.databases.each.dbname}' postgres
      figlet -f bubble DONE! DONE! DONE!
  EOT


---
I have this variable: variable "databases" {
  type        = list(map(object({
    dbname = string
    dbhost = string
    dbpass = string
    script_name = string
    username = string
    exclude_tables = string
    })))
} 
and I need a terraform template which I can use for creating a metadata_startup_script prameter for my vm instance like this 
resource "google_compute_instance" "default" {
  project = var.project
  zone = var.zone
  name         = "db-dump"
  machine_type = "e2-medium"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  resource_policies = [
    google_compute_resource_policy.hourly.id
  ]

  network_interface {
    network = "default" 
  #  access_config {}
  }

  metadata_startup_script = <<EOT
      export DEBIAN_FRONTEND=noninteractive 
      sudo apt update && sudo apt -y upgrade
      if ! which psql; then
        sudo sh -c 'echo 'deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main' > /etc/apt/sources.list.d/pgdg.list'
        wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - 
        sudo apt-get update; sudo apt install -y postgresql-14 postgresql-client-14;
      fi
      [ -d /dumps ] || mkdir /dumps && chown -R postgres:postgres /dumps
      cd /dumps
      gsutil cp gs://${google_storage_bucket.dumps.name}/${var.script_name}.sql .
      chown postgres:postgres ${var.script_name}.sql
      PGPASSWORD=${var.dbpass} pg_dump -h ${var.dbhost} -U ${var.username} -O ${var.dbname} ${var.exclude_tables} > ${var.dbname}.sql
      chown postgres:postgres ${var.dbname}.sql
      su -c 'createdb ${var.dbname}' postgres
      su -c 'psql ${var.dbname} < ${var.dbname}.sql' postgres
      su -c 'psql ${var.dbname} < ${var.script_name}.sql' postgres
      su -c 'pg_dump -O -Z 9 ${var.dbname} > anonymized-dump.sql.gz' postgres
      gsutil cp anonymized-dump.sql.gz gs://${google_storage_bucket.dumps.name}
      su -c 'dropdb ${var.dbname}' postgres
      echo "DONE DONE DONE DONE DONE DONE DONE DONE DONE DONE DONE DONE DONE DONE DONE DONE DONE"
  EOT
  service_account {
    email = google_service_account.db-backups.email
    scopes = ["cloud-platform"]
  }
}