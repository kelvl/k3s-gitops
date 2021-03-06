#!/usr/bin/env bash

export REPO_ROOT=$(git rev-parse --show-toplevel)

need() {
    which "$1" &>/dev/null || die "Binary '$1' is missing but required"
}

need "kubeseal"
need "kubectl"
need "sed"
need "envsubst"


set -a
. "${REPO_ROOT}/secrets/.secrets.env"
set +a

PUB_CERT="${REPO_ROOT}/secrets/pub-cert.pem"

# Helper function to generate secrets
kseal() {
  echo "------------------------------------"
  # Get the path and basename of the txt file
  # e.g. "deployments/default/pihole/pihole-helm-values"
  secret="$(dirname "$@")/$(basename -s .txt "$@")"
  echo "Secret: ${secret}"
  # Get the filename without extension
  # e.g. "pihole-helm-values"
  secret_name=$(basename "${secret}")
  echo "Secret Name: ${secret_name}"
  # Extract the Kubernetes namespace from the secret path
  # e.g. default
  namespace="$(echo "${secret}" | awk -F /deployments/ '{ print $2; }' | awk -F / '{ print $1; }')"
  echo "Namespace: ${namespace}"
  # Create secret and put it in the applications deployment folder
  # e.g. "deployments/default/pihole/pihole-helm-values.yaml"
  envsubst < "$@" | tee values.yaml \
    | \
  kubectl -n "${namespace}" create secret generic "${secret_name}" \
    --from-file=values.yaml --dry-run=client -o json \
    | \
  kubeseal --format=yaml --cert="$PUB_CERT" \
    > "${secret}.yaml"
  # Clean up temp file
  cat values.yaml
  rm values.yaml
}

#
# Helm Secrets
#

kseal "${REPO_ROOT}/deployments/default/home-assistant/home-assistant-helm-values.txt"
kseal "${REPO_ROOT}/deployments/default/traefik-forward-auth/traefik-forward-auth-helm-values.txt"
kseal "${REPO_ROOT}/deployments/default/transmission/transmission-helm-values.txt"
kseal "${REPO_ROOT}/deployments/default/jackett/jackett-helm-values.txt"
kseal "${REPO_ROOT}/deployments/default/radarr/radarr-helm-values.txt"
kseal "${REPO_ROOT}/deployments/default/sonarr/sonarr-helm-values.txt"

#
# Generic Secrets
#

# Flux Cloud - default Namespace
kubectl create secret generic fluxcloud \
  --from-literal=slack_url="$SLACK_URL" \
  --namespace flux --dry-run=client -o json \
  | \
kubeseal --format=yaml --cert="$PUB_CERT" \
    > "$REPO_ROOT"/deployments/flux/fluxcloud/fluxcloud-secrets.yaml

# # NginX Basic Auth - default Namespace
# kubectl create secret generic nginx-basic-auth \
#   --from-literal=auth="$NGINX_BASIC_AUTH" \
#   --namespace default --dry-run -o json \
#   | \
# kubeseal --format=yaml --cert="$PUB_CERT" \
#     > "$REPO_ROOT"/deployments/kube-system/nginx-ingress/basic-auth-default.yaml

# # NginX Basic Auth - kube-system Namespace
# kubectl create secret generic nginx-basic-auth \
#   --from-literal=auth="$NGINX_BASIC_AUTH" \
#   --namespace kube-system --dry-run -o json \
#   | \
# kubeseal --format=yaml --cert="$PUB_CERT" \
#     > "$REPO_ROOT"/deployments/kube-system/nginx-ingress/basic-auth-kube-system.yaml



