#!/usr/bin/env sh

cork_script_path=$(realpath "$0")

# Utils

_err() {
    tput setaf 1
    tput bold
    printf '%s' '==> '
    tput sgr0
    tput bold
    echo "$@"
    tput sgr0
    return 1
}

_suberr() {
    tput setaf 1
    tput bold
    printf '%s' ' -> '
    tput sgr0
    tput bold
    echo "$@"
    tput sgr0
    return 1
}

_msg() {
    tput setaf 2
    tput bold
    printf '%s' '==> '
    tput sgr0
    # tput bold
    echo "$@"
    tput sgr0
}

_submsg() {
    tput setaf 12
    tput bold
    printf '%s' ' -> '
    tput sgr0
    # tput bold
    echo "$@"
    tput sgr0
}

_fail() {
    _err "$@"
    exit 1
}

_read_byte() {
    saveterm="$(stty -g)" # save terminal state
    stty raw
    stty -echo -icanon min 1 time 0       # prepare to read one byte
    var="$(dd ibs=1 count=1 2>/dev/null)" # read one byte
    stty -icanon min 0 time 0             # prepare to read lefotvers
    while read none; do :; done           # read leftovers
    stty "$saveterm"                      # restore terminal state
    echo "$var"
}

_confirm() {
    printf '%s' "$(tput setaf 2)$(tput bold)==>$(tput sgr0) $1 [y/n]: "
    input="$(_read_byte)"
    printf '%s' '\n'
    case "$(echo "$input" | tr '[:upper:]' '[:lower:]')" in
    y) return 0 ;;
    *) return 1 ;;
    esac
}

kak_ensure_session() {
    kak_session="${kak_session:-$KAKOUNE_SESSION}"
    if [ -z "$kak_session" ]; then
        kak_session="$(mktemp -u "cork-background-session-XXXXXXXX")"
        kak -d -s "$kak_session" >/dev/null &
        pid=$!
        trap "kill $pid" EXIT
        _msg "No kakoune session detected. Started headless temporary session at pid $pid"
    fi
}

kak_send() {
    kak_ensure_session
    echo "$@" | kak -p "$kak_session"
}

kak_get_opt() {
    kak_ensure_session
    opt=$1
    shift
    d=$(mktemp -d -t cork.XXXXXXXX)
    trap "rm -rf $d" EXIT
    mkfifo "$d/fifo"
    echo "echo -to-file '$d/fifo' %opt[$opt]" | kak -p "$kak_session"
    cat "$d/fifo"
}

# Functions

cork_help() {
    cat <<EOF

A git-based plugin manager for kakoune.

Setup:

  1. Install the cork script (for example to \`~/.local/bin\`)

  2. In the beginning of your \`kakrc\`, add
       evaluate-commands %sh{
         cork init
       }

  3. Declare plugins in your kakrc using the \`cork\` command:
       cork tmux https://github.com/alexherbo2/tmux.kak %{
         tmux-integration-enable
       }
     The first parameter is an arbitrary unique name for each plugin
     The second parameter is the location of the git repository
     The third parameter (usually a block) is optional, and contains
     code that will be run when the plugin is loaded.

  4. Install/update plugins using \`:cork-update\`, or by running
     \`cork update\` in a terminal.

Usage:
  cork <command> [args...]

Commands:
  update          Install/Update all plugins.
  clean [name]    Delete the folder of the plugin by name [name], or
                  all plugins if no name is provided
  list            List all plugins
EOF
}

setup_load_file() {
    name=$1

    folder="$install_path/$name"
    echo "echo -debug [cork]: Loading plugin $1..." >"$folder/load.kak"

    find -L "$folder/repo" -type f -name '*\.kak' ! -path '*test*' ! -path "$folder/repo/colors/*" |
        sed 's/.*/source "&"/' \
            >>"$folder/load.kak"

    if [ -d "$folder/repo/colors" ]; then
        echo "set -add global colorscheme_sources '$folder/repo/colors'" >>"$folder/load.kak"
    fi

    echo "trigger-user-hook cork-loaded=$name" >>"$folder/load.kak"
}

cork_update() {
    kak_ensure_session
    install_path="$(kak_get_opt cork_install_path)"

    cork_list | while read -r name repo; do
        folder="$install_path/$name"
        mkdir -p "$folder"

        if ! [ -d "$folder/repo" ]; then
            _msg "Installing plugin $name → $repo"
            git clone "$repo" "$folder/repo"
            setup_load_file "$name"
            kak_send source "$folder/load.kak"
        else
            _msg "Updating plugin $name → $repo"
            (cd "$folder/repo" && git pull)
            setup_load_file "$name"
        fi
        echo ""
    done
}

cork_clean() {
    kak_ensure_session
    install_path="$(kak_get_opt cork_install_path)"
    rm -irf "${install_path:?}/${1:?}" && _msg "Done"
}

cork_interactive() {
    cmd=$1
    shift
    "cork_$cmd" "$@"
    echo ""
    echo "Done!"
    printf '%s' "Press any key to exit"
    input="$(_read_byte)"
    printf '%s' '\n'
}

cork_list() {
    kak_ensure_session
    kak_get_opt cork_repository_map | tr ' ' '\n' | while read -r name; do
        read -r repo
        echo "$name $repo"
    done
}

cork_init() {
    echo "declare-option -docstring 'cork script' str cork_script_path '$cork_script_path'"
    cat <<EOF
# kakscript to initialize cork
# Use by adding the following to the top of your kakrc:
# evaluate-commands %sh{
#   cork init
# }

declare-option -docstring 'cork list of name and repository pairs' str-list cork_repository_map
declare-option -hidden -docstring 'cork requires update' bool cork_requires_update false

# Paths
declare-option -hidden -docstring 'cork XDG_DATA_HOME path' str cork_xdg_data_home_path %sh(echo "${XDG_DATA_HOME:-$HOME/.local/share}")

declare-option -docstring 'cork install path' str cork_install_path "%opt{cork_xdg_data_home_path}/cork/plugins"

define-command -override cork -params 2..3 -docstring 'cork <name> <repository> [config]' %{
  set-option -add global cork_repository_map %arg{1} %arg{2}
  hook global -group cork-loaded User "cork-loaded=%arg{1}" %arg{3}
  try %{
    source "%opt[cork_install_path]/%arg[1]/load.kak"
  } catch %{
    remove-hooks global cork-update-reminder
    hook -group cork-update-reminder global ClientCreate .* %{
      echo -markup "{Error}[cork]: Plugins require an update! run cork-update"
    }
    echo -debug "[cork]: plugin '%arg{1}' not installed"
    echo -markup "{Error}[cork]: plugin '%arg{1}' not installed - run cork-update"
  }
}

define-command -override cork-update %{
  try %{
    cork-interactive update
  } catch %{
    fail "Could not run cork-update. Run \$(cork update) manually in a terminal"
  }
}

define-command -override cork-interactive -hidden -params 1.. %{
  try %{
    popup env "kak_session=%val{session}" %opt{cork_script_path} interactive %arg{@}
  } catch %{
    terminal env "kak_session=%val{session}" %opt{cork_script_path} interactive %arg{@}
  }
}
EOF
}

# Evaluate

cmd=${1:-help}
shift
"cork_$cmd" "$@"
