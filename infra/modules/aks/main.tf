resource "azurerm_kubernetes_cluster" "this" {
  name                      = var.name
  dns_prefix                = var.dns_prefix
  resource_group_name       = var.resource_group_name
  location                  = var.location
  kubernetes_version        = var.kubernetes_version
  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  automatic_upgrade_channel = "patch"
  node_resource_group       = "${var.resource_group_name}-nodes"

  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_node_vm_size
    node_count                   = var.system_node_count
    vnet_subnet_id               = var.system_subnet_id
    os_disk_size_gb              = 30
    only_critical_addons_enabled = true
    tags                         = var.tags
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    network_data_plane  = "cilium"
    service_cidr        = "10.200.0.0/16"
    dns_service_ip      = "10.200.0.10"
    pod_cidr            = "10.244.0.0/16"
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
  }

  oms_agent {
    log_analytics_workspace_id      = var.log_analytics_id
    msi_auth_for_monitoring_enabled = true
  }

  azure_policy_enabled = false

  tags = var.tags

  lifecycle {
    ignore_changes = [
      kubernetes_version,
      default_node_pool[0].node_count,
    ]
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = var.user_node_vm_size
  os_disk_size_gb       = 50
  vnet_subnet_id        = var.system_subnet_id
  mode                  = "User"

  auto_scaling_enabled = true
  min_count            = var.user_node_min_count
  max_count            = var.user_node_max_count

  node_labels = {
    "workload" = "apps"
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [node_count]
  }
}

# Kubelet (pulled-image identity) → AcrPull on the registry
resource "azurerm_role_assignment" "kubelet_acr_pull" {
  scope                            = var.acr_id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}
