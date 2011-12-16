DARK_CYAN='\033[00;36m'
X='\033[00m'

case "$TERM" in
  xterm*|screen)
    PS1="\[\e]0;\h: \w\a\]\[$DARK_CYAN\]\W\[$X\] \\\$ "
    ;;
  *)
    PS1="\h:\w\\\$ "
    ;;
esac

os-vpx-info
