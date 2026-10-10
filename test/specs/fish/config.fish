# vim: ft=fish

# XDG Directories
set -Ux XDG_CONFIG_HOME "$HOME/.config"
set -Ux XDG_CACHE_HOME "$HOME/.cache"
set -Ux XDG_DATA_HOME "$HOME/.local/share"
set -Ux XDG_STATE_HOME "$HOME/.local/state"
set -Ux XDG_DATA_DIRS "/usr/local/share:/usr/share"
set -Ux XDG_CONFIG_DIRS "/etc/xdg"

# set -gx HISTCONTROL=ignoredups
# set -gx HISTSIZE=-1
# set -gx HISTFILESIZE=
# set -gx HISTFILE="$HOME/.bash_history"

set -Ux W3M_DIR "$XDG_CONFIG_HOME/w3m"
set -Ux ANDROID_HOME "$HOME/.android"
set -Ux JAVA_HOME "/usr/lib/jvm/default"
set -Ux EDITOR nvim
set -Ux SUDO_EDITOR $EDITOR
set -Ux VISUAL $EDITOR
set -Ux PAGER "bat --plain"
set -Ux MANOPT "--nh --nj"

set -Uxa --path PKG_CONFIG_PATH "/usr/local/pkgconfig"
set -Uxa --path PKG_CONFIG_PATH "/usr/local/lib/pkgconfig"

fish_add_path -a "$ANDROID_HOME/cmdline-tools/latest/bin"
fish_add_path -a "$ANDROID_HOME/tools"
fish_add_path -a "$ANDROID_HOME/tools/bin"
fish_add_path -a "$ANDROID_HOME/platform-tools"
fish_add_path -a "$JAVA_HOME/bin"
fish_add_path -a "$HOME/.odin"
fish_add_path -a "$HOME/.ghcup/bin"
fish_add_path -a "$HOME/.local/bin"
fish_add_path -a "$HOME/.nimble/bin"
fish_add_path -a "$HOME/.local/state/gem/ruby/3.0.0/bin"
fish_add_path -a "$HOME/.dvm/bin/"
fish_add_path -a "$HOME/dev/deps/flutter/bin"

# bun
set -Ux BUN_INSTALL "$HOME/.bun"
fish_add_path -a "$BUN_INSTALL/bin"

if test -f ~/.cargo/env
  chmod +x ~/.cargo/env
  ~/.cargo/env
end

# # ref: https://unix.stackexchange.com/questions/320465/new-tmux-sessions-do-not-source-bashrc-file
# if [ -n "$BASH_VERSION" -a -n "$PS1" ]; then
#   if [ -f "$HOME/.bashrc" ]; then
#     . $HOME/.bashrc
#   fi
# fi

if status is-interactive
  fish_vi_key_bindings
end
