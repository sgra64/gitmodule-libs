# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Disable zsh to output ANSI escape chars in sub-processes $(...),
# setopt no_match: disable 'no matches found:' message in zsh.
type setopt 2>/dev/null | grep builtin >/dev/null
[ $? = 0 ] && trap "" DEBUG && setopt no_nomatch

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Grouping of '.jar' libraries in local installation packages.
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
# Install '.jar' libraries from URL's from the '.bom' (bill-of-materials) file.
# Execute installation commands with the '--exec' option.
# Usage:
# - install.sh [--exec]
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function install_bom() {
    # probe 'curl' or 'wget' are installed to download libraries from URL
    if [ "$(which curl 2>/dev/null)" ]; then
        local has_curl=true
    elif [ "$(which wget 2>/dev/null)" ]; then
        local has_wget=true
    else
        echo -e "no 'curl' or 'wget' commands installed, download libraries from URL manually\n"
    fi
    [ "$1" = "--exec" ] && local execute=true
    # 
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
                [ ! -d "$locpth" ] && echo "mkdir -p $locpth" && [ "$execute" ] && mkdir -p "$locpth"
                # 
                [ "$has_curl" ] && local cmd="curl -o \"$locjar\" -L \"$url\" 2>/dev/null"
                [ "$has_wget" ] && local cmd="wget -O \"$locjar\" \"$url\" 2>/dev/null"
                echo $cmd                       # show command
                [ "$execute" ] && eval $cmd     # execute command
            else
                echo "echo install '$locjar' from '$url'"
            fi
        fi
    done; true ) || echo "no .bom (bill-of-materials) file found"
}

install_bom $@
