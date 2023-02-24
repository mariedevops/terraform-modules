#SOME ACC WE DON'T NEED

resource "google_service_account" "db-backups" {
  project = var.project
  account_id   = "db-backups"
  display_name = "Service Account"
} 

#JUNK
data "google_project" "gcp_project" {
  project_id = var.project
}

#BINDING
resource "google_project_iam_binding" "project" {
  project = var.project
  role    = "roles/compute.instanceAdmin.v1"

  members = [
    "serviceAccount:service-${data.google_project.gcp_project.number}@compute-system.iam.gserviceaccount.com",
  ]
}

# #BINDING2
# resource "google_project_iam_binding" "gsutil" {
#   project = var.project
#   role    = "roles/storage.objectAdmin"

#   members = [
#     "serviceAccount:${data.google_project.gcp_project.number}-compute@developer.gserviceaccount.com",
#   ]
# }

#INSTANCE
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
        sudo apt-get update; sudo apt install -y postgresql-14 postgresql-client-14 figlet;
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
      figlet -f bubble DONE! DONE! DONE!
  EOT
  service_account {
    email = google_service_account.db-backups.email
    scopes = ["cloud-platform"]
  }
}

#STARTUP SCHEDULE
resource "google_compute_resource_policy" "hourly" {
  name   = "startup-dump-server"
  project = var.project
  region = var.location
  description = "Start and stop instance"
  instance_schedule_policy {
    vm_start_schedule {
      schedule = "0 12 * * *"
    }
    vm_stop_schedule {
      schedule = "0 13 * * *"
    }
    time_zone = "Europe/Amsterdam"
  }
}

#BUCKET
resource "google_storage_bucket" "dumps" {
  name          = "${var.bucket_prefix}-anonymized-dumps"
  location      = var.location
  project       = var.project
  storage_class = "REGIONAL"
  uniform_bucket_level_access = true
  force_destroy = true 
}

#PRIVS
resource "google_storage_bucket_iam_member" "member" {
  bucket = google_storage_bucket.dumps.name
  role = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.db-backups.email}"
}

resource "google_storage_bucket_iam_member" "access" {
  bucket = google_storage_bucket.dumps.name
  role = "roles/storage.objectAdmin"
  member = "group:cluster-developers@remarkgroup.com"
}

#ANONYMIZATION SCRIPT
resource "google_storage_bucket_object" "anon" {
  name   = "${var.script_name}.sql"
  source = "/Users/Marinadin.Grin/repositories/remark-terraform/modules/remark-environment-migrate/scripts/${var.script_name}.sql"
  bucket = google_storage_bucket.dumps.name
}