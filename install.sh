#!/bin/sh
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Disable zsh to output ANSI escape chars in sub-processes $(...),
# setopt no_match: disable 'no matches found:' message in zsh.
type setopt 2>/dev/null | grep builtin >/dev/null
[ $? = 0 ] && trap "" DEBUG && setopt no_nomatch

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Group '.jar' files into local installation packages.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
declare -gA packages=(
    [jackson-annotations]="jackson"
    [jackson-core]="jackson"
    [jackson-databind]="jackson"

    [apiguardian-api]="junit"
    [junit-jupiter-api]="junit"
    [junit-platform-commons]="junit"
    [opentest4j]="junit"

    [junit-platform-console-standalone]="."

    [log4j-api]="logging"
    [log4j-core]="logging"
    [log4j-slf4j2-impl]="logging"
    [slf4j-api]="logging"

    [jacocoagent.jar]="jacoco"
    [jacococli.jar]="jacoco"

    [lombok]="lombok"
)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# The 'install' command shows and(or) fetches .jar libraries from URL's from
# the '.bom' (bill-of-materials) file.
# Flag '-v' shows .jar files to download, flag '-f' fetches and installs .jar
# files into package sub-directories.
# Flag '--wipe' removes packages, flag '--wipe-all' also removes functions.
# 
# Usage:
# - install [-v|--show] [-f|--fetch] [--help] [--wipe|--wipe-all]
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function install() {
    local show_jars=""; local fetch_jars=""
    # 
    local args=(); local sp=""
    [ -z "$@" ] && install --help && return 0 ||
        for arg in $@; do
            case "$arg" in
            -v|--show) local show_jars=true ;;
            -f|--fetch) local fetch_jars=true ;;
            --wipe-all) wipe --all; return 0 ;;
            --wipe) wipe; return 0 ;;
            --help) echo "usage: install [-v|--show] [-f|--fetch] [--help] [--wipe|--wipe-all]"
                    return 0
                    ;;
            *) args+="$sp$arg"; sp=" " ;;
            esac
        done
    # 
    if [ "$show_jars" -o "$fetch_jars" ]; then
        # 
        # probe 'curl' or 'wget' are present to download .jars from URL
        [ "$(which curl 2>/dev/null)" ] && local has_curl=true
        [ -z "$has_curl" -a "$(which wget 2>/dev/null)" ] && local has_wget=true
        # 
        if [ -z "$has_curl" -a -z "$has_wget" ]; then
            echo -e "commands 'curl' or 'wget' are not found, download .jar files manually from URL\n"
        else
            [ -f .bom ] && ( grep '^http' < .bom | while read url
            do
                local jar=${url##http*/}    # cut until last slash, local jar=$(basename "$url")
                local path=${url%/*}        # cut after last slash, local path=$(dirname "$url")
                local nam=${jar/-[0-9\.]*.jar/}     # stip version leaving name to look up in ${packages[$nam]}
                local pck=${packages[$nam]}         # looked up package
                [ -z "$pck" ] && pck="." && echo "could not group into package: \"$jar\", use \".\""
                local f=$pck/$jar           # e.g.: lombok/lombok-1.18.38.jar
                local locpth="${f%/*}"
                local locjar="$locpth/$jar"
                # 
                if [ ! -f "$locjar" ]; then
                    if [ "$has_curl" -o "$has_wget" ]; then
                        # 
                        [ ! -d "$locpth" ] && echo "mkdir -p $locpth" && [ "$fetch_jars" ] && mkdir -p "$locpth"
                        # 
                        [ "$has_curl" ] && local cmd="curl -o \"$locjar\" -L \"$url\" 2>/dev/null"
                        [ "$has_wget" ] && local cmd="wget -O \"$locjar\" \"$url\" 2>/dev/null"
                        echo $cmd                       # show command
                        [ "$fetch_jars" ] && eval $cmd  # execute command
                    else
                        echo "echo install '$locjar' from '$url'"
                    fi
                fi
            done; true ) || echo "no .bom (bill-of-materials) file found"
        fi
    fi
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# The 'wipe' command removes downloaded packakges. Flag '--all' also removes
# functions and defintions.
# Usage:
# - wipe [--all] [--help]
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function wipe() {
    [ "$1" = "--help" ] && echo "usage: wipe [--all] [--help]" && return 0
    declare -A pgks     # store packages as keys
    # for zsh, iterate over 'pgks' keys using:
    # - https://superuser.com/questions/737350/iterating-over-keys-or-k-v-pairs-in-zsh-associative-array
    for k in "${!packages[@]}"; do
        local v="${packages[$k]}"
        [ "$v" != "." -a "$v" ] && pgks[$v]=$v
    done
    for jar in *.jar; do
        pgks[$jar]=$jar
    done
    for pgk in "${!pgks[@]}"; do
        [ -e "$pgk" ] && echo "rm -rf $pgk" && rm -rf "$pgk" && local removed=true
    done
    # 
    [ "$1" = "--all" -a "$(declare -p packages 2>/dev/null)" ] && local removed=true &&
        local cmd="unset packages" && echo "$cmd" && eval $cmd
    # 
    [ "$1" = "--all" ] && local rm_funcs=() &&
        for func in install wipe; do
            if typeset -f $func >/dev/null; then
                rm_funcs+=($func)
                local print_wiping=true
            fi
        done && [ "${rm_funcs[@]:0:1}" ] && local removed=true &&
        local cmd="unset -f ${rm_funcs[@]}" && echo "$cmd" && eval $cmd
    # 
    [ -z "$removed" ] && echo "nothing to wipe"
}
