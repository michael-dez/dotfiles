# az helpers; skipped without az. Why: docs/bash.md#az
_have az || return 0

# git-bash rewrites /subscriptions/... args into Windows paths. Why: docs/bash.md#git-bash
if [[ $OSTYPE == msys* || $OSTYPE == cygwin* ]]; then
  az() { MSYS_NO_PATHCONV=1 command az "$@"; }
fi

# tsv for capture; strips the CR that az emits on Windows. Why: docs/bash.md#git-bash
_az_tsv() { az "$@" -o tsv | tr -d '\r'; }

# Keep the header rows, filter the rest by case-insensitive regex.
_az_grep() { awk -v p="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" 'NR <= 2 || tolower($0) ~ p'; }

azw() {
  az account show -o table \
    --query '{subscription:name, id:id, user:user.name, tenant:tenantId, cloud:environmentName}'
}

azl() {
  local mode=${1:-}
  (( $# )) && shift
  if [[ -z $mode ]]; then
    if [[ -n ${ARM_CLIENT_ID:-} ]]; then mode=mi; else mode=dc; fi
  fi
  case $mode in
    mi)
      if [[ -z ${ARM_CLIENT_ID:-} ]]; then
        az login --identity -o none "$@"
      elif az login --help 2>/dev/null | grep -q -- '--client-id'; then
        az login --identity --client-id "$ARM_CLIENT_ID" -o none "$@"
      else
        az login --identity --username "$ARM_CLIENT_ID" -o none "$@"
      fi ;;
    dc) az login --use-device-code -o none "$@" ;;
    *) echo "usage: azl [mi|dc] [az login args]" >&2; return 2 ;;
  esac && azw
}

azs() {
  local line id
  line=$(_az_tsv account list --query '[].[name, id]' | grep -i -- "${1:-}" | _pick) || return 1
  id=${line##*$'\t'}
  az account set -s "$id" && export ARM_SUBSCRIPTION_ID=$id && azw
}

azc() {
  if [[ -z ${1:-} ]]; then
    az cloud list --query '[].{name:name, active:isActive}' -o table
    return
  fi
  az cloud set -n "$1" && echo "cloud set to $1; run azl to log in" >&2
}

# ARM_* from the current az context, for terraform. Auth vars are left alone.
azenv() {
  local sub tenant cloud arm_env
  IFS=$'\t\n' read -r -d '' sub tenant cloud \
    < <(_az_tsv account show --query '[id, tenantId, environmentName]')
  [[ -n $cloud ]] || return 1
  case $cloud in
    AzureCloud) arm_env=public ;;
    AzureUSGovernment) arm_env=usgovernment ;;
    AzureChinaCloud) arm_env=china ;;
    *) echo "azenv: unknown cloud $cloud" >&2; return 1 ;;
  esac
  export ARM_SUBSCRIPTION_ID=$sub ARM_TENANT_ID=$tenant ARM_ENVIRONMENT=$arm_env
  printf 'ARM_SUBSCRIPTION_ID=%s\nARM_TENANT_ID=%s\nARM_ENVIRONMENT=%s\n' "$sub" "$tenant" "$arm_env"
}

azrg() {
  az group list -o table \
    --query '[].{name:name, location:location, state:properties.provisioningState}' |
    _az_grep "${1:-}"
}

azr() {
  local rg=${1:-}
  [[ -n $rg ]] || rg=$(_az_tsv group list --query '[].name' | _pick) || return 1
  az resource list -g "$rg" -o table --query '[].{name:name, type:type, location:location}'
}

azvm() {
  local args=()
  [[ -n ${1:-} ]] && args=(-g "$1")
  az vm list -d "${args[@]}" -o table \
    --query '[].{name:name, rg:resourceGroup, state:powerState, private:privateIps, public:publicIps, size:hardwareProfile.vmSize}'
}

for _f in /etc/bash_completion.d/azure-cli /usr/share/bash-completion/completions/az; do
  [[ -r $_f ]] && { . "$_f"; break; }
done
unset _f
