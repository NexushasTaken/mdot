function psql
  if command -s psql
    PAGER='nvim --clean -R' command psql $argv
  else
    command psql
  end
end
