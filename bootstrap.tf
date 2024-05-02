 
data "kustomization_build" "argo" {
  path = "infra/argocd"
}

resource "kustomization_resource" "argocd" {
  for_each = data.kustomization_build.argo.ids

  manifest = data.kustomization_build.argo.manifests[each.value]


  depends_on = [module.eks, helm_release.cilium, kustomization_resource.cert-manager, kustomization_resource.external-secrets]
}
