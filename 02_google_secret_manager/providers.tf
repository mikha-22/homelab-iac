provider "google" {
  project = var.project_id # example of not hardcoded values, it fetches from the variables file
  region  = var.region 
}
