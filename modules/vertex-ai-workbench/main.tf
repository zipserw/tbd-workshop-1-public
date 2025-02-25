data "google_project" "project" {
  project_id = var.project_name
}

locals {
  zone                = "${var.region}-b"
  gce_service_account = "${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

resource "google_project_service" "notebooks" {
  provider           = google
  service            = "notebooks.googleapis.com"
  disable_on_destroy = true
}


resource "google_storage_bucket" "notebook-conf-bucket" {
  #checkov:skip=CKV_GCP_62: "Bucket should log access"
  name          = "${var.project_name}-conf"
  location      = var.region
  force_destroy = true

  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
}


resource "google_storage_bucket_iam_binding" "binding" {
  bucket = google_storage_bucket.notebook-conf-bucket.name
  role   = "roles/storage.objectViewer"
  members = [
    "serviceAccount:${local.gce_service_account}"
  ]
}


resource "google_storage_bucket_object" "post-startup" {
  name   = "scripts/notebook_post_startup_script.sh"
  source = "${path.module}/resources/notebook_post_startup_script.sh"
  bucket = google_storage_bucket.notebook-conf-bucket.name
}



resource "google_notebooks_instance" "tbd_notebook" {
  depends_on   = [google_project_service.notebooks]
  location     = local.zone
  machine_type = "e2-standard-2"
  name         = "${var.project_name}-notebook"
  container_image {
    repository = var.ai_notebook_image_repository
    tag        = var.ai_notebook_image_tag
  }
  network             = var.network
  subnet              = var.subnet
  instance_owners     = [var.ai_notebook_instance_owner]
  post_startup_script = "gs://${google_storage_bucket_object.post-startup.bucket}/${google_storage_bucket_object.post-startup.name}"
  no_public_ip        = true
}

