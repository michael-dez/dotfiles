# packer shortcuts; all act on the current directory. Why: docs/bash.md#packer
_have packer || return 0

alias pk=packer
complete -C packer packer pk

pki() { packer init "$@" .; }
pkv() { packer fmt -recursive . && packer validate "$@" .; }
pkb() { packer build -timestamp-ui "$@" .; }
