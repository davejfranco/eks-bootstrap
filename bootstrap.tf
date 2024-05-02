#argocd namespace
resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = "argocd"
  }

  depends_on = [module.eks, null_resource.kubectl]
}

data "kustomization_build" "argo" {
  path = "bootstrap/argocd"
}

resource "kustomization_resource" "argocd" {
  for_each = data.kustomization_build.argo.ids

  manifest = data.kustomization_build.argo.manifests[each.value]


  depends_on = [module.eks, null_resource.kubectl, kubernetes_namespace_v1.argocd]
}
