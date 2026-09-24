#!/usr/bin/env bash
##[bin/build.sh]
# build a demo's Dockerfile (if applicable)
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
declare -a DEMOS

for dir in demos/*/; do
  if [[ -e "${dir}/Dockerfile" ]]; then
    DEMOS+=("$dir")
  fi
done

select-demo(){
  read -rp "build tag: " tag
  PS3="build demo: "
  select demo in "$(basename "${DEMOS[@]}")"; do
    pushd "demos/$demo" || return 1
      sudo docker build -t "$tag" .
    popd || return 1
    break
  done
};
select-demo "$@"