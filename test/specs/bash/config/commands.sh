#!/usr/bin/env bash
# vim: ft=bash
alias psql="PAGER='nvim --clean -R' psql"

codoo() {
  systemctl is-active --quiet postgresql
  [[ $? -ne 0 ]] && sudo systemctl start postgresql
  ODOO_PATH=~/odoo-dev
  local addons_path="--addons-path=$ODOO_PATH/addons,$ODOO_PATH/odoo/addons"
  local cmd='odoo'
  local args=''

  add_path() {
    local path=$(realpath $1)
    if [[ -d $path ]]; then
      for dir in $(exa -D $path); do
        if [[ -f "$path/$dir/__init__.py" ]]; then
          addons_path+=",$path"
          return 0
        fi
      done
    fi
  }
  add_path .

  for i in $(seq 5); do
    case $1 in
      init)
        args+=" -i all"
        shift
      ;;paths)
        shift
        for dir in ${1//,/ }; do
          add_path $dir
        done
        shift
      ;;db)
        args="$args -d $(basename $(pwd))"
        shift
      ;;shell)
        cmd+=" shell"
        shift
      ;;dev)
        cmd+=" --dev=xml,reload,qweb,pdb,werkzeug"
        shift
    esac
  done

  unset add_path
  $PREFIX $cmd -D $PWD/.cache/odoo $args $addons_path $@
}

conda-activate() {
  eval "$(/home/nexus/miniconda3/bin/conda shell.bash hook)"
}

alias 'git-state'='git status -s; git submodule status'

flutter-dev-start() {
  if [[ $(tmux list-panes | wc -l) -gt 1 ]]; then
    echo "A window must only have 1 pane"
    return 1
  fi

  if [[ ! -d "$PWD/lib/" ]]; then
    echo "Is this cwd a flutter project?"
    return 1
  fi

  local window_name="flutter-dev"
  tmux rename-window "$window_name"

  local current_session=$(tmux display-message '#S')
  local window="$current_session:$window_name"
  local run_flutter="flutter run"
  local run_hot_reload="r"

  tmux split-pane
  tmux send-keys -t "$window.2" "$run_flutter" Enter

  while read file; do
    if [[ "$file" = *.dart ]]; then
      tmux send-keys -t "$window.2" "$run_hot_reload" Enter
    fi
  done < <(inotifywait -m -r -e modify,create,delete --format '%w%f' --include '.*\.dart$' "$PWD/lib")
}
