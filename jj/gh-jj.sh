#!/usr/bin/env sh
BOLD=$(tput bold)
RESET=$(tput sgr0)

SCRIPTDIR="$(cd "$(dirname "$(realpath "$0")")" && /bin/pwd -P)"
MY_TTY="$(readlink /proc/$$/fd/1)"

__short_usage() {
  cat <<EOF
${BOLD}Usage:${RESET}
    ${BOLD}gh jj${RESET} or ${BOLD}gh-jj.sh${RESET}
      [${BOLD}-h|--help]${RESET} SUBCOMMAND [${BOLD}SUBCOMMAND_ARGS${RESET}] [-- [${BOLD}--jj-args${RESET} JJ_ARGS...] [${BOLD}--gh-args${RESET} GH_ARGS...] [${BOLD}--git-args${RESET} GIT_ARGS...]]

Entry point script for \`jj\` subcommand to the \`gh\` CLI, adding Jujutsu integration to GitHub workflows.

Use the long flag ${BOLD}--help${RESET} for more information.
EOF
}

__usage() {
  __short_usage
  cat <<EOF

These subcommands are meant to be injected in to the \`gh\` CLI via \`gh alias\`. The only alias actually registered with the \`gh\` cli is \`gh jj\`. Everything
else will be injected as follows:

Subcommands are implemented as \`gh-jj-<subcommand>.sh\` files in this directory. You can extend this alias by adding your own \`gh-jj-<subcommand>.sh\` files to your \$PATH.

If a subcommand extension meets the following conditions:

- the script is in the same directory on the \$PATH as this script,
- the script accepts a \`--describe\` flag

Then the command will be enumerated in the list of subcommands presented in this usage string.

${BOLD}Exported Environment for Subcommands${RESET}

Subcommands will inherit the calling environment as normal, with the following additional environment variables
provided by this alias:

  ${BOLD}MY_TTY${RESET}                         The TTY file descriptor for the command if one is allocated
  ${BOLD}GH_ARGS${RESET}                        Args that should be applied to the \`gh\` cli
  ${BOLD}GIT_ARGS${RESET}                       Args that should be forwarded to \`git\` via the \`gh\` cli.
  ${BOLD}JJ_ARGS${RESET}                        Args that should be forwarded to \`jj\`.


${BOLD}Automagic Argument Forwarding for \`git\`/\`gh\`/\`jj\`{$RESET}

Additional ${BOLD}root command${RESET} arguments/options/parameters for \`git\`, \`gh\`, or \`jj\` can provided
after the options/arguments/parameters to the alias subcommand using \`-- [--git-args|--gh-args|--jj-args]\`.

Subcommands will be run in an environment where the normal commands have the arguments collected
by the alias autommagically applied.

If any of \`git\`/\`gh\`/\`jj\` get run within a subcommand, they will be run using injected wrapper
functions that modify the functions in the following way:

- git -> git \$GIT_ARGS [...]
- gh ->  gh \$GH_ARGS [...] -- \$GIT_ARGS
- jj -> jj \$JJ_ARGS [...]

See help text for individual subcommands for more information.

${BOLD}Built-in Subcommands:${RESET}
EOF
  for subcmd in "$SCRIPTDIR"/gh-jj-*.sh; do
    without_prefix="${subcmd#*gh-jj-}"
    without_suffix="${without_prefix%.sh}"
    description=$($subcmd --describe 2>/dev/null)
    if [ -n "$description" ]; then
      printf "  %s%s:%s\t\t\t%s\n" "$BOLD" "$without_suffix" "$RESET" "$description"
    fi
  done
}

# shellcheck disable=SC2059
__die() {
  _msg="$1"
  shift
  printf "$_msg\n" "$@" 1>&2
  __short_usage
  exit 1
}

_collecting_additional_args=false
_collecting_gh_args=false
_collecting_jj_args=false
_collecting_git_args=false

_cmd=""
_subcmd=
_gh_args=
_git_args=
_jj_args=
_subcmd_args=

while test $# -gt 0; do
  handled=false
  case "$1" in
  -h)
    __short_usage
    return 0
    ;;
  --help)
    __usage
    return 0
    ;;
  --)
    if [ -n "$_subcmd" ]; then
      _collecting_additional_args=true
      handled=true
    else
      __die "attempt to begin collecting forwarded arguments ended without specifying a subcommand"
    fi
    ;;
  --git-args)
    if [ "$_collecting_additional_args" = true ]; then
      _collecting_gh_args=false
      _collecting_jj_args=false
      _collecting_git_args=true
      handled=true
    fi
    ;;
  --gh-args)
    if [ "$_collecting_additional_args" = true ]; then
      _collecting_gh_args=true
      _collecting_jj_args=false
      _collecting_git_args=false
      handled=true
    fi
    ;;
  --jj-args)
    if [ "$_collecting_additional_args" = true ]; then
      _collecting_gh_args=false
      _collecting_jj_args=true
      _collecting_git_args=false
      handled=true
    fi
    ;;
  *)
    if [ "$_collecting_gh_args" = true ]; then
      _gh_args="${_gh_args}$1 "
      handled=true
    elif [ "$_collecting_git_args" = true ]; then
      _git_args="${_git_args}$1 "
      handled=true
    elif [ "$_collecting_jj_args" = true ]; then
      _jj_args="${_jj_args}$1 "
      handled=true
    elif [ -z "$_subcmd" ] && command -v "gh-jj-$1.sh" 1>/dev/null 2>&1; then
      _subcmd="gh-jj-$1.sh"
      handled=true
    elif [ -n "$_subcmd" ]; then
      _subcmd_args="$_subcmd_args$1"
      handled=true
    else
      __die "Unexpected argument: %s\n" "$1"
    fi
    ;;
  esac

  if [ "$handled" = true ]; then
    handled=false
    shift
  fi
done

export GH_ARGS="$_gh_args"
export GIT_ARGS="$_git_args"
export JJ_ARGS="$_jj_args"
export MY_TTY

_real_git="$(which git)"
_real_gh="$(which gh)"
_real_jj="$(which jj)"

#export _real_git
#export _real_gh
#export _real_jj

_shebang_shell="$(sed -n '1 s/^#!\(.*\)$/\1/gp' "$(which "$_subcmd")")"

cat <<EOF | $_shebang_shell -s "$_subcmd_args"
#!${_shebang_shell:-/usr/bin/env sh}

git() {
  $_real_git $_git_args \$*
}

jj() {
  $_real_jj $_jj_args \$*
}

gh() {
  if [ -z "$_git_args" ]; then
    $_real_gh $_gh_args \$*
  else
    $_real_gh $_gh_args \$* -- $_git_args
  fi
}
$(
  sed '1 s/^#!.*$//g' "$(which "$_subcmd")"
)
EOF
