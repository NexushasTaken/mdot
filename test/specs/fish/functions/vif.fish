function vif -d "Run fzf and then edit the file in nvim"
  set -l file $(fzf)
  test -n "$file" && nvim "$file"
end
