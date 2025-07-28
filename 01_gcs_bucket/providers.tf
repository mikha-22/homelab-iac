# For this provider what is the configs, or the values for the variables
provider "google" {
  # Project is "homelab-secret-manager" / this is still hardcoded, it's possible to fetch from the shared folder
  project = "homelab-secret-manager"     
  # GCP Project region is asia-southeast1, singapore I believe
  region  = "asia-southeast1"
}
