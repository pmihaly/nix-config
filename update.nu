#! /usr/bin/env nix-shell
#! nix-shell -i nu -p nushell

let flakesToNotUpdate = [ "finances" ]

def main [] {
  nix flake metadata --json
  | from json
  | $in.locks.nodes
  | transpose key value
  | where { $in.value.original? != null }
  | $in.key
  | where { parse -r ".*_[0-9]*$" | is-empty }
  | where { $in not-in $flakesToNotUpdate }
  | par-each {|it| nix flake lock --update-input $it }
  | ignore
}
