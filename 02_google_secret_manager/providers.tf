provider "google" {
  # example of not hardcoded values, it fetches from the variables file
  project = var.project_id 
  region  = var.region 
}
