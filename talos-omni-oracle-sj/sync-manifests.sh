#!/bin/bash

export KUBECONFIG=kubeconfig

declare -A helm_releases=(
  ["cilium"]="kube-system"
  ["coredns"]="kube-system"
  ["kubelet-serving-cert-approver"]="kubelet-serving-cert-approver"
)

declare -A patch_path_values=(
  ["cilium"]=".cluster.network.cni.urls[0]"
  ["coredns"]=".cluster.extraManifests[1]"
  ["kubelet-serving-cert-approver"]=".cluster.extraManifests[0]"
)

declare -A patches=(
  ["cilium"]="cilium-cni.yaml"
  ["coredns"]="extra-manifests.yaml"
  ["kubelet-serving-cert-approver"]="extra-manifests.yaml"
)

for release in "${!helm_releases[@]}"; do
  namespace=${helm_releases[$release]}
  values_file="manifests/${release}/values.yaml"
  install_file="manifests/${release}/install_$(date +'%Y-%m-%d_%H-%M-%S').yaml"
  export git_manifest_file="https://raw.githubusercontent.com/neilmfrench/omni-manifests/refs/heads/main/talos-omni-oracle-sj/${install_file}"
  export path_value="${patch_path_values[$release]}"
  patch_file="patches/${patches[$release]}"

  echo "Processing Helm release: $release in namespace: $namespace"

  if kubectl get helmrelease "$release" -n "$namespace" -o yaml &>/dev/null; then
    kubectl get helmrelease "$release" -n "$namespace" -o yaml | yq eval '.spec.values' - > "$values_file"
    kustomize build --enable-helm "manifests/${release}" > "$install_file"
    yq 'eval(env(path_value))=env(git_manifest_file)' -i "$patch_file"
    echo "Updated manifests for $release"
  else
    kustomize build "manifests/${release}" > "$install_file"
    yq 'eval(env(path_value))=env(git_manifest_file)' -i "$patch_file"
  fi
done


