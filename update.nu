#! /usr/bin/env nix-shell
#! nix-shell -i nu -p nushell

let flakesToNotUpdate = [ "finances" ]

def main [] {
  nix flake metadata --json
  | from json
  | $in.locks.nodes
  | transpose key value
  | filter { $in.value.original? != null }
  | $in.key
  | filter { parse -r ".*_[0-9]*$" | is-empty }
  | filter { $in not-in $flakesToNotUpdate }
  | par-each {|it| nix flake lock --update-input $it }
  | null
}
