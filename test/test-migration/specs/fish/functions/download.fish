function download -d "Download from link"
  argparse h/help c/curl w/wget -- $argv
  or return

  function usage
    echo "usage: download [FLAGS] <url> <output> [...]"
    echo "FLAGS"
    echo "  -h|--help Print this help"
    echo "  -c|--curl Use curl to download"
    echo "  -w|--wget Use wget to download"
  end

  if [ $_flag_help ]
    usage
    return
  end

  if not set -q $_flag_wget $_flag_curl
    set -f _flag_wget --wget
  end

  # # Get URL and output
  set -f url "$argv[1]"
  set -f out "$argv[2]"

  if test -z "$url" || test -z "$out"
    usage
    return 1
  end

  if [ $_flag_wget ]
    echo wget --passive-ftp -c -O "$out" "$url" $argv[3..]
  else if [ $_flag_curl ]
    echo curl -L -C - -f -o "$out" "$url" $argv[3..]
  end
end
