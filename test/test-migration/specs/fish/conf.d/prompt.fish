set -gx __fish_git_prompt_show_informative_status true
set -gx __fish_git_prompt_showdirtystate true
set -gx __fish_git_prompt_showuntrackedfiles true
set -gx __fish_git_prompt_showupstream "verbose" # auto,verbose,name,informative,git,svn,none
set -gx __fish_git_prompt_showstashstate true
set -gx __fish_git_prompt_shorten_branch_len # number
set -gx __fish_git_prompt_describe_style "branch" # contains,branch,describe,default
set -gx __fish_git_prompt_showcolorhints true

set -gx __fish_git_prompt_char_stateseparator ''

function fish_prompt
  # stat: Status {
  set -f save_status $status
  [ $save_status -ne 0 ] && set -fa stat "$(set_color red)$save_status"
  fish_is_root_user && set -fa stat "$(set_color yellow)#"
  [ (jobs | wc -l) -gt 0 ] && set -fa stat "$(set_color cyan)~"
  [ $stat ] && set -f stat "[$stat$(set_color normal)]"
  # }

  # git: Git {
  set -f git_state (fish_git_prompt | string trim)
  # }

  # gas: Git state and Status (git|stat) {
  set -f gas (string join '' -- "$git_state" "$stat")
  # }

  # sep: Separator (gas) {
  [ -z $gas ] && set -fa separator '  ' || set -fa separator ' 󰁔 '
  set -f separator "$(set_color blue)$separator$(set_color normal)"
  # }

  set -fa uname "$(set_color green)$(whoami)$(set_color normal)"
  set -fa hname "$(set_color blue)$(prompt_hostname)$(set_color normal)"
  set -fa host (string join '@' -- $uname $hname)

  if [ -z $gas ]
    set -f host "($host)"
  else
    set -f host "$host:"
  end
  set -f dir (prompt_pwd -d 0)

  string join '' -- $host $gas $separator $dir
  printf "\$ "
end
