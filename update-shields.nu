#! /usr/bin/env nix-shell
#! nix-shell -i nu -p nushell

def main [] {
  nix flake metadata --json
  | from json
  | $in.locks.nodes
  | transpose key value
  | where { $in.value.original? != null }
  | $in.key
  | where { parse -r ".*_[0-9]*$" | is-empty }
  | where { "-shield" in $in }
  | each {|it| nix flake lock --update-input $it }
  | ignore
}
