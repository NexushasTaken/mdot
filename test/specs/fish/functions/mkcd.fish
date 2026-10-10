function mkcd -d "Make and Change to that directory"
  mkdir "$argv[1]" && cd "$argv[1]"
end
