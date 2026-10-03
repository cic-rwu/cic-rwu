#!/usr/bin/env bash
##
# simple script to set git options to use gpg keys for signing commits and tags
##
declare -A GIT_OPTIONS=(
  [user.name]=""
  [user.email]=""
  [user.signingkey]=""
  [commit.gpgsign]=true
  [tag.gpgsign]=true
)
GPG_INSTALLED=$(command -v gpg)
GIT_OPTIONS["user.name"]="$(read -rp 'Enter your GitHub username: ' input && echo "$input")"
GIT_OPTIONS["user.email"]="$(read -rp 'Enter your GitHub email: ' input && echo "$input")"

update-git() {
  for opt in "${!GIT_OPTIONS[@]}"; do
    if [[ -z "${GIT_OPTIONS[$opt]}" ]]; then
      echo "Skipping $opt as it is empty."
      continue
    fi
    git config --global "$opt" "${GIT_OPTIONS[$opt]}"
  done
  printf "Updated git configuration with the following settings:\n%s\n" "$(git config --global --list)" && return 0
}

main(){
  echo 'Listing GPG keys...'
  if [[ -n "$GPG_INSTALLED" ]]; then
    gpg --list-secret-keys --keyid-format LONG
    GIT_OPTIONS["user.signingkey"]="$(read -rp 'Enter your GPG key ID (the long string after sec): ' input && echo "$input")"
    [[ -z "${GIT_OPTIONS["user.signingkey"]}" ]] && echo "No GPG key ID provided. Exiting." && exit 1
    update-git
  else
    echo "GPG is not installed. Please install GPG to use this script."
    exit 1
  fi
}; main "$@"
