variable "gcp_project" {
  description = "Name of GCP project used to provision infrastructure into"
}

variable "gcp_region" {
  description = "GCP region to provision resources into"
}

variable "subnet_cidr" {
  description = "Subnet used to provision resources into"
}

variable "router_asn" {
  description = "ASN used for the router. Needs to be a valid ASN number not use elsewhere"
  default     = 64512
}

variable "datadog_api_key" {
  description = "Datadog API key"
}

variable "datadog_app_key" {
  description = "Datadog APP key"
}

variable "omgnetwork_vpc_uri" {
  description = "URI of the client VPC to be peered to the Vault VPC"
}

variable "omgnetwork_subnet_cidr" {
  description = "CIDR block of subnet used when allowing ingress access in Vault VPC firewall"
}

variable "bucket_name" {
  description = "Bucket where OpenVPN config file is stored"
}


variable "ssh_user_email" {
  description = "Email of user allowed to SSH into VPN instance for troubleshooting purposes"
}

variable "allow_ssh" {
  description = "Boolean indicating if SSH access to VPN instance is configured"
  default     = false
}

variable "lockdown_egress" {
  description = "Boolean indicating if egress network access is lockdown to only Datadog IPs"
  default     = false
}

variable "gke_cluster_name" {
  description = "Name of the GKE Kubernetes cluster to create"
}

variable "gke_node_count" {
  description = "The number of nodes to create in the GKE node pool"
  default     = 1
}