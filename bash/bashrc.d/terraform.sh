# terraform shortcuts. Why: docs/bash.md#terraform
_have terraform || return 0

alias tf=terraform
complete -C terraform terraform tf

export TF_PLUGIN_CACHE_DIR=${TF_PLUGIN_CACHE_DIR:-$HOME/.terraform.d/plugin-cache}
mkdir -p "$TF_PLUGIN_CACHE_DIR"

tfi() { terraform init "$@"; }
tfv() { terraform fmt -recursive && terraform validate "$@"; }
tfp() { terraform plan -out=tfplan "$@"; }
tfa() { terraform apply "$@" tfplan; }
tfw() {
  if [[ -n ${1:-} ]]; then terraform workspace select "$1"; else terraform workspace list; fi
}
