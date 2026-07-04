#!/bin/bash
# shellcheck disable=SC2059
# shellcheck disable=SC2064
# shellcheck disable=SC2034
# shellcheck disable=SC2086
# ^ 
#
#==========================================================
#
#       FILE:           /usr/local/bin/preserve
#       USAGE:          ./preserve [OPTION] {SOURCE} {DESTINATION}
#       DESCRIPTION:    Compresses, checksums, and copies folders and files from {SOURCE} to {DESTINATION}
#
#       AUTHOR:         MXHML (mxhml@proton.me)
#       VERSION:        1.0.0
#       CREATED:        July 2, 2026
#       REVISION:       0
#
#==========================================================

#set -euo pipefail
#shopt -s extglob
trap cleanup EXIT
cleanup(){
    rm "$tmpfile"
}
#[ -d /opt/cicpreserve ] || mkdir /opt/cicpreserve 
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
WORK_DIR="/opt/cicpreserve/"
DEBUG=1
CH_SUM_BIN="b3sum"
tmpfile="$(mktemp)"

# import cic custom logging script
. "$SCRIPT_DIR/ciclogger.sh" || { log error "Failed to find ciclogger file."; exit 1; }





#help message output
printf -v SCRIPT_OPTS "
    ${BO}Usage: preserve [OPTION] {SOURCE} {DEST}${NOFO}

    ${ITAL}Automatically compress and checksum files from a source to a destination

    With no FILE, or when FILE is -, read standard input.
        
        ${BO}-x, --no-extended${NOFO}
            Check for and add extended attributes to files with attr(1)

            ${ITAL}Extended attributes are supported by most common Linux filesystems like
            BTRFS, XFS, EXT4/3/2, but ${BO}does not work on VFAT, exFAT, or NFS filesystems.${NOFO}

        ${BO}-h, --help
            Display this help message${NOFO}
"


#===preserve.sh checkpath() doc===#
# checkpath {FILE/FOLDER}
# Check the validity of a given path and return the dirname(1) and relevant extended
# attributes of the file.
#
# If no FILE/FOLDER, check the fstype of the current directory
# EXIT CODES:
#   0       FILE/FOLDER/fstype is OK
#   1       Bad file/folder or sub-command error)
#   2       Bad filesystem (see the `-x` option)
#
checkpath() {
    if [[ -n "$1" || ! -f "$1"  ]]; then
        log error "Bad path, or file already exists!" path "${1}"
    fi

    case "$1" in
        source ) rp="$(realpath "$1" 2> "$tmpfile")"
                if [[ -n "$rp" && ! -s "$tmpfile" ]] #if rp is nonzero and the tempfile (stderr) does NOT have a size > 0.
                     
                ;;
    esac

    # attempt to resolve the real path of the argument. store stderr in ${tmpfile} to be evaluated later
    tpath="$(realpath "$1" 2>"$tmpfile")"
    if [[ ${#tpath} -gt 0 && "$(cat $tmpfile)" -eq 0 ]]; then
        tsize="$(stat -c %s "$tpath")"
        ttype="$(stat -c "%F" "$tpath")"
        [ "$ttype" == "directory" ] && tsize=$(( tsize-4096 )) # folders will always have a minimum size of 4096
        log debug "File Type" stat "$(stat -c "%F" ${tpath})" # expansion is okay here; path had to be resolved previously to get here
        if [[ $tsize -eq 0 && "$ttype" != "directory" ]]; then log error "Bad path? Found ${tsize} bytes" path "${tpath}"; return 1; fi
    else
        log error "Bad path?" stderr "$(cat "$tmpfile")"
        exit 1
    fi
    fstype="$(findmnt -rn -o FSTYPE -T "$(dirname $tpath)")"

    # if fstype is unsupported, log an error and exit with a special status
    if [[ "$fstype" == !(ext2|ext3|ext4|btrfs|xfs) ]]; then log error "bad fstype!" fstype "$fstype"; return 2; fi
    echo "$tpath"
    return 0
}

checksum(){
    checksum="$($CH_SUM_BIN $tpath 2>"$tmpfile")"
    if which "$CH_SUM_BIN" 1> /dev/null; then
        # full BSD-style checksum
        checksum="$($CH_SUM_BIN --tag $tpath)"
        # just the checksum, without the preceeding information
        puresum="$(echo $checksum | cut -d' ' -f4)"
        # full CH_SUM_BINithm name, gathered after the checksum is generated
        algfname="$(echo "$checksum" | cut -d' ' -f1)"
        [ "${#puresum}" -le 32 ] && log warn "Checksum is less than 32 characters?" "$algfname" "$puresum"
        log info "Generated checksum" "$algfname" "$puresum"
    else
        cat $tmpfile
        return 1
    fi
    (
        cd "$(dirname $tpath)" || exit 1
        echo "$checksum" > "${tpath}.${algfname,,}"
    )
    chsumfile="${tpath}.${algfname,,}"
    chmod 600 "$chsumfile"
    [ $DEBUG -eq 0 ] && echo "$checksum"
}

main(){
    for arg in ${1}; do
        if checkpath "$arg"; then
            log info "Path $arg is OK"
        fi
        if checksum "$tpath"; then
            log info "Checksum OK." "$algfname" "$puresum"
        fi
        echo "
        FILE: $1
        RESOLVED NAME: $tpath
        CHECKSUM FILE: $chsumfile
        CHECKSUM ALGORITHM: $algfname
        "
    done
}

compress(){
    case "$1" in
        tar )
            tar --acls --xattrs -I 'zstd -T0' -caf "$1.tar.zst"
            log info "Done compressing $1" path "$1.tar.zst"
        ;;
    esac
}

main "$*"