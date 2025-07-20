provider "google" {                   # For this provider what is the configs, or the values for the variables
  project = "homelab-secret-manager"  # Project is "homelab-secret-manager" / this is still hardcoded, it's possible
                                      # to fetch from the shared folde
  region  = "asia-southeast1"         # GCP Project region is asia-southeast1, singapore i believe
}
