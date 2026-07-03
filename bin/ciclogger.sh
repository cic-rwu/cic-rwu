#!/bin/bash
#==========================================================
#
#       FILE:           /usr/local/bin/ciclogger
#       USAGE:          log [LEVEL] {MESSAGE}
#       DESCRIPTION:    Standardize log handling for CIC
#
#       AUTHOR:         MXHML (mxhml@proton.me)
#       VERSION:        1.0.0
#       CREATED:        July 2, 2026
#       REVISION:       0
#
#==========================================================

# This script will default to using gum(1) (https://github.com/charmbracelet/gum) for formatting logs.
# Otherwise, it will generate (less detailed) custom logs.
# This script also defines some common tput(1) formatting variables

BO=$(tput bold)
ULIN=$(tput smul)
NOFO=$(tput sgr0)
ITAL=$(tput sitm)
DIM=$(tput dim)
RED=$(tput setaf 1)
GR=$(tput setaf 2)

# log [LEVEL] message {key} {value}
# uses gum(1), if available
log(){
    [ $# -eq 2 ] && set -- "$@" "" ""
    gum log --time timeonly --prefix="${FUNCNAME[1]}" -sl "$1" "$2" "$3" "$4"
    sleep 0.5s
}

export BO ULIN NOFO ITAL DIM log