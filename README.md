## EKS Bootstrap

This repo demonstrate how to bootstrap a EKS clusters using Terraform + ARGOCD

### Requirements

- kubectl
- aws-cli
- terraform
- aws account

### How this works

Terraform is in charge of deploying the necessary infrastructure resources including: VPC, EKS and the IAM Roles needed for the cluster componenets to work. Then by using kubernetes and kustomization providers after all the infra gets deployed ArgoCD gets installed. 

#### Quick Note
This is an example on how to control the installation order so that the cluster gets created before trying to connect to it and deploy ArgoCD

```hcl

/* Provider Configuration */
resource "null_resource" "kubectl" {
  provisioner "local-exec" {
    command = "aws eks --region ${var.region} update-kubeconfig --name ${module.eks.cluster_name} --profile ${var.profile} --kubeconfig $(pwd)/.kube/config"
  }
  depends_on = [module.eks]
}

# Generate Kubeconfig 
data "local_file" "kubeconfig" {
  filename   = ".kube/config"
  depends_on = [null_resource.kubectl]
}

provider "kustomization" {
  #kubeconfig_path = data.local_file.kubeconfig.filename
  kubeconfig_raw = data.local_file.kubeconfig.content
}

# This data source is necessary to configure the Kubernetes provider
data "aws_eks_cluster" "cluster" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "cluster" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

# In case of not creating the cluster, this will be an incompletely configured, unused provider, which poses no problem.
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}
```
Notice the use of `depends_on` and `local_file` to control when the kustomization providers gets enabled.


### ArgoCD 

ArgoCD is the GitOps tool use for deploying the internal cluster components such as:

- external-dns
- external-secrets
- ack (Amazon Controller for Kubernetes)

After the cluster gets created a kustomize resource in the `bootstrap.tf` deploys the installation of argo, creates this repo and deploys an application resource which tracks the `bootstrap/core` directory. This approach follows the app-of-apps patter in the ArgoCD documentation, that you can read [here](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/) 

### How to use this proyect

Make sure you have you have all the pre-requisites and the aws cli tool configured. There are two variables `region` and `profile` to control to which aws region to deploy and which credentials profile to use. Also go to the `botstrap/core` directory and modify the account id in the IAM role of the service account annotation (There has to be a way to update this dinamically)

To apply:

```shell
terraform init && terraform apply
```
Once everything gets install, the kubeconfig file gets created in the root of the proyect so to connect to the cluster:

```shell
export KUBECONFIG=.kube/config
kubectl get pods -n argocd 
```
You can port forward argocd service.

```shell
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
and finally to get the credentials.

```shell
kubectl get secrets argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode
```
### To clean everything 

I've got problems while trying to destroy everything due to a problem on how terraform calculates the order to destroy resources. So in order to clean everything I recomment the following:

```shell
tf state rm 'data.kustomization_build.argo'
tf state rm 'kubernetes_namespace_v1.argocd'
tf destroy
```
Frist remove the kustomize part from the state file and the delete the cluster, VPC and IAM roles 



