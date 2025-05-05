#!/usr/bin/env sh

BOLD=$(tput bold)
RESET=$(tput sgr0)
SCRIPTDIR="$(cd "$(dirname "$(realpath "$0")")" && /bin/pwd -P)"

__usage() {
  cat <<EOF
${BOLD}Usage:${RESET}

  ${BOLD}install.sh${RESET}
    [${BOLD}-h|--help${RESET}] [${BOLD}--script-install-dir${RESET} DIR]
    [${BOLD}--clobber${RESET}] [${BOLD}--clobber-aliases${RESET}] [${BOLD}--clobber-scripts${RESET}]
    [${BOLD}--dump-yaml${RESET}] [${BOLD}--no-import${RESET}] [${BOLD}--no-install${RESET}]

Copies all alias entrypoints and alias subcommands to ${BOLD}\$HOME/.local/bin${RESET} or to the path
indicated with ${BOLD}--script-install-dir${RESET}, then installs them by generating YAML and piping it
to ${BOLD}gh alias import -${RESET} unless ${BOLD}--no-import${RESET} is set. Otherwise the YAML is written
to ${BOLD}stdout${RESET}

If ${BOLD}--no-install${RESET} is set, then the scripts will not be copied in to the installation directory
at all. A convenience flag ${BOLD}--dump-yaml${RESET} is provided for this.

All log messages are printed to ${BOLD}stderr${RESET}. The only information printed to ${BOLD}stdout${RESET} is
the generated YAML if ${BOLD}--no-import${RESET} is set, so it can be easily piped or redirected.

${BOLD}--no-install --no-import${RESET} can be combined to generate the relevant YAML without the pre-existence
checks, which may be useful if you need to audit or make a backup of the alias definitions that would be
imported.

If an alias entrypoint or subcommand already exists in the installation directory, the script will fail.
If you want to overwrite existing files, use ${BOLD}--clobber-scripts${RESET}

If there are any alias collisions, the ${BOLD}gh alias import${RESET} command will fail. If you want to
override existing aliases, use ${BOLD}--clobber-aliases${RESET}.

You can also use ${BOLD}--clobber${RESET} as shorthand for ${BOLD}--clobber-scripts --clobber-aliases${RESET}
EOF
}

# shellcheck disable=SC2059
__die() {
  _msg="$1"
  shift
  printf "$_msg\n" "$@" 1>&2
  __usage
  exit 1
}

install_dir="$HOME/.local/bin"
clobber_aliases=1
clobber_scripts=1
do_import=0
do_install=0

while test $# -gt 0; do
  case "$1" in
  -h | --help)
    __usage
    return 0
    ;;
  --clobber-scripts)
    clobber_scripts=0
    ;;
  --clobber-aliases)
    clobber_aliases=0
    ;;
  --clobber)
    clobber_aliases=0
    clobber_scripts=0
    ;;
  --no-import)
    do_import=1
    ;;
  --no-install)
    do_install=1
    ;;
  --dump-yaml)
    do_install=1
    do_import=1
    ;;
  --script-install-dir)
    install_dir="$2"
    shift
    ;;
  esac
  shift
done

mkdir -p "$install_dir"

aliases=

for f in "$SCRIPTDIR"/*; do
  if [ -d "$f" ]; then
    maybe_alias="$(basename "$f")"
    maybe_alias_script="gh-${maybe_alias}.sh"
    for script in "$f"/*.sh; do
      script_file="$(basename "$script")"
      if [ "$maybe_alias_script" = "$script_file" ]; then
        printf "${BOLD}Found alias entrypoint %s${RESET}\n" "$maybe_alias_script" >&2
        aliases="$aliases$maybe_alias "
      fi

      if [ "$do_install" -eq 0 ]; then
        if [ -f "$install_dir"/"$script_file" ] && [ "$clobber_scripts" -ne 0 ]; then
          __die "cannot install script, %s already exists\n" "$install_dir"/"$script_file"
        fi
        printf "${BOLD}Installing %s to %s${RESET}\n" "$script_file" "$install_dir" >&2
        install -m '775' "$script" "$install_dir/"
      fi
    done
  fi
done

printf '\n' >&2

yaml=
for target in $aliases; do
  yaml="$yaml$target: \"! gh-${target}.sh \$@\"
"
done

if [ "$do_import" -eq 0 ]; then
  gh_args="-"
  if [ "$clobber_aliases" -eq 0 ]; then
    gh_args="--clobber $gh_args"
  fi
  cat "$SCRIPTDIR"/aliases.yaml - <<EOF | gh alias import $gh_args
$(printf '%s' "$yaml")
EOF
else
  cat "$SCRIPTDIR"/aliases.yaml - <<EOF
$(printf '%s' "$yaml")
EOF
fi
