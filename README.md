# `gh-contrib`

A collection of aliases for extending the functionality of the [GitHub CLI (`gh`)](https://cli.github.com/),
and a framework for authoring said aliases.

The GitHub CLI allows for defining two types of aliases:

- "Expansion" type aliases, where you can define a word that expands to a full
  subcommand with its relevant arguments/options/parameters
- "Shell" type aliases, which are strings that get passed to the system's `sh`.

This is a framework for leveraging the latter shell aliases; as such, it is
primarily a collection of POSIX shell scripts (all of them are shebang'd to
`#!/usr/bin/env sh`).

More information can be found in the `gh` CLI's help page for `gh alias`: <https://cli.github.com/manual/gh_alias>

In particular, the help page for `gh alias set` tends to be the most informative
section about the structure of aliases.

## Installation

The `./install.sh` script can be used to get all of the shell scripts on to your
`$PATH` and imported in to the
`gh` CLI.

Detailed usage of the install script is provided by `./install.sh --help`

## Concepts

### `aliases.yaml`

The top-level `aliases.yaml` file is a collection of simple extensions to the
`gh cli` that don't require complicated argument parsing, sub-command handling,
or otherwise require their own binary. They're either expansion aliases or shell
aliases that don't require additional tools and can be expressed as "one-liners".

They're basically just some useful things one might find themselves wanting to
automate. These aliases are combined with the alias entrypoints when the install
script is run.

### Alias Entrypoint

The framework enables the creation of aliases that themselves have their own
subcommands, options/arguments/parameters, etc. But rather than generating
an individual shell alias for each potential subcommand of the new top-level
alias that we're introducing, we leverage a pattern that is reminiscent of the
way that one would go about extending `git`; we use special naming conventions
for the executables that implement the various commands, and each top-level alias
that we introduce has a main script call the "entrypoint" that handles dispatching
to the various sub-commands, as well as arg parsing conventions for that particular
"namespace".

Each top-level directory in this repository represents a top-level alias, or if you
prefer, you can think of them as "namespaces".

The entrypoint script for each alias/namespace represented by `$dir` would be `$dir/gh-$dir.sh`.
Sub-commands for each namespace are implemented as `$dir/gh-$dir-$subcmd.sh`

### Extending Existing Namespaces

Existing namespaces can be extended by creating a shell script that meets the following
conditions:

1. It must following the naming conventions for the namespace you want to extend,
   as described above
2. It must *not only* be on your `$PATH`, but *also* must be reachable as a sibling
   of entrypoint script for the namespace you are extending.
   1. For example, to extend the `jj` namespace with the new command `foo`, you would
      need to create `gh-jj-foo.sh` and place it in the same directory that
      `gh-jj.sh` is installed to. A symlink that is a sibling to `gh-jj.sh` will
      also work.
3. \[Optional\] If your extension script responds to the `--description` flag
   by printing a string on `stdout`, then your extension will show up in the list
   of subcommands in the usage string for the namespace's `--help` output.

### Adding New Namespaces

> [!NOTE]
> Not yet implemented, but the concepts outlined here are easily generalizable, and I intend
> to provide that eventually.

## List of Aliases/Namespaces

## License

`gh-contrib` is available as Open Source Software, under the MIT license. See
[`LICENSE`](./LICENSE) for details about copyright and redistribution.
