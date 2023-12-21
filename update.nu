#! /usr/bin/env nix-shell
#! nix-shell -i nu -p nushell parallel

def main [] {
  nix flake metadata --json
  | from json
  | $in.locks.nodes
  | items {|k| $k}
  | filter {$in != "finances"}
  | filter {parse -r ".*_[0-9]*$" | is-empty}
  | to text
  | parallel "nix flake lock --update-input {} || exit 0"
}
