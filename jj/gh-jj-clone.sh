#!/usr/bin/env sh

while test $# -gt 0; do
  case "$1" in
  --describe)
    printf "clone a github repo using \`gh repo clone\`, then initialize a colocated JJ repository\n"
    return 0
    ;;

  -*)
    printf "Unexpected option/flag %s\n" "$1" 1>&2
    return 1
    ;;
  *)
    break
    ;;
  esac
  shift
done

BOLD=$(tput bold)
CMD_COLOR=$(tput setaf 6)
RESET=$(tput sgr0)

# shellcheck disable=SC2016
clone_cmd='gh repo clone "$1" -- --single-branch 2>&1'

if [ -n "$MY_TTY" ]; then
  clone_cmd="$clone_cmd --progress | tee $MY_TTY"
fi

printf "[%s]\n" "${BOLD}${CMD_COLOR}gh repo clone${RESET}"
if ! result="$(eval "$clone_cmd")"; then
  printf "%s" "$result" >&2
  exit 1
fi

dir="$(printf "%s" "$result" | sed -n -e "s/Cloning into '\([^']*\)'.*$/\1/p")"

echo
printf "[%s]\n" "${BOLD}${CMD_COLOR}jj git init --colocate${RESET}"
jj --config "git.auto-local-bookmark=true" git init --colocate "$dir"
jj -R "$dir" git fetch --all-remotes
