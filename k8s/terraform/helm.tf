/*
 * Helm Release - https://www.terraform.io/docs/providers/helm/r/release.html
 * Installs the Consul Helm chart with value overrides
 * This depends on the Consul gossip key existing in K8S secrets
 * prior to attempting to install the Helm chart
 */
resource "helm_release" "consul_chart" {
  name      = "omisego-consul"
  chart     = "../helm/consul"
  namespace = var.k8s_namespace

  atomic          = true
  cleanup_on_fail = true

  set {
    name  = "global.certificatesSecretNamePrefix"
    value = var.k8s_certificates_secret_name_prefix
  }

  set {
    name  = "global.image"
    value = local.consul_img
  }

  set {
    name  = "global.imageK8S"
    value = local.consul_k8s_img
  }

  set {
    name  = "global.datacenter"
    value = var.consul_datacenter
  }

  set {
    name  = "global.gossipKey"
    value = data.vault_generic_secret.consul_gossip_key.data["value"]
  }

  set {
    name  = "server.replicas"
    value = var.consul_replicas
  }

  set {
    name  = "server.bootstrapExpect"
    value = var.consul_bootstrap_expect
  }
}

/*
 * Helm Release - https://www.terraform.io/docs/providers/helm/r/release.html
 * Installs the Vault Helm chart with value overrides
 * This depends on the Consul Helm chart being installed already
 */
resource "helm_release" "vault_chart" {
  depends_on = [helm_release.consul_chart]
  name       = "omisego-vault"
  chart      = "../helm/vault"
  namespace  = var.k8s_namespace

  atomic          = true
  cleanup_on_fail = true

  set {
    name  = "global.certificatesSecretNamePrefix"
    value = var.k8s_certificates_secret_name_prefix
  }

  /*
   * https://cloud.google.com/kubernetes-engine/docs/tutorials/http-balancer
   * If the cluster context is not local/minikube, then the Vault service will be set
   * to be of type `LoadBalancer` which will trigger an automatic GCP load balancer to
   * be created to manage the inboudn traffic to the specified service in the manifest
   */
  set {
    name  = "global.loadBalancer"
    value = true
  }

  set {
    name  = "server.image"
    value = local.vault_img
  }

  set {
    name  = "server.acl.token"
    value = var.recovery ? data.vault_generic_secret.consul_vault_token.0.data["value"] : data.kubernetes_secret.vault_acl_token.0.data.token
  }

  set {
    name  = "server.replicas"
    value = var.vault_replicas
  }

  set {
    name  = "server.mlockDisabled"
    value = false
  }

  set {
    name  = "server.unseal.address"
    value = var.unsealer_vault_addr
  }

  set {
    name  = "server.unseal.token"
    value = data.vault_generic_secret.unseal_token.data["value"]
  }

  set {
    name  = "consul.image"
    value = local.consul_img
  }

  set {
    name  = "consul.acl.token"
    value = var.recovery ? data.vault_generic_secret.consul_client_token.0.data["value"] : data.kubernetes_secret.client_acl_token.0.data.token
  }

  set {
    name  = "consul.datacenter"
    value = var.consul_datacenter
  }

  set {
    name  = "consul.gossipKey"
    value = data.vault_generic_secret.consul_gossip_key.data["value"]
  }
}