
# Copyright 2014 Georgia Tech Research Corporation (GTRC). All rights reserved.

# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.

# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.

# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

set -o nounset -o errexit

configure_script_path="$0"

config_decls_m4=config-decls.m4

unset config_bin_dir
unset config_stow_packages_dir
unset config_stow_package_dir
unset config_stow_package_share_dir
unset config_package_name
unset config_prefix
unset config_share_dir

fail () {
    printf "%s: Error: %s\n" "$configure_script_path" "$*" >&2
    exit 1
}

opt_help () {
    (( $# == 0 )) || fail "opt_help expects no arguments"
    grep -e "^#HELP:" "$0" | sed -e 's/^#HELP://' | m4 -P -D COMMAND_NAME="$configure_script_path"
    exit 0
}

#HELP:  --prefix=$dir | -p $dir: set installation directory to $dir
opt_prefix () {
    (( $# == 1 )) || fail "opt_prefix() expects one argument"
    [[ ! -e $1 || -d $1 ]] || fail "argument to --prefix must not exist, or must be a directory"
    config_decl_set_prefix "$1"
}

# set macros that require multiple macros to be set. Figure out what
# can be set and set those.
config_set_shared () {
    if [[ is-set != ${config_share_dir+is-set} \
              && is-set = ${config_package_name+is-set} \
              && is-set = ${config_prefix+is-set} ]]
    then config_share_dir="$config_prefix/share/$config_package_name"
         config_decl_set CONFIG_SHARE_DIR "$config_share_dir"
    fi
    if [[ is-set != ${config_stow_package_dir+is-set} \
              && is-set = ${config_stow_packages_dir+is-set} \
              && is-set = ${config_package_name+is-set} ]]
    then config_stow_package_dir="$config_stow_packages_dir/$config_package_name"
         config_decl_set CONFIG_STOW_PACKAGE_DIR "$config_stow_package_dir"
    fi
    if [[ is-set != ${config_stow_package_share_dir+is-set} \
              && is-set = ${config_stow_packages_dir+is-set} \
              && is-set = ${config_package_name+is-set} ]]
    then config_stow_package_share_dir=$config_stow_package_dir/share/$config_package_name
         config_decl_set CONFIG_STOW_PACKAGE_SHARE_DIR "$config_stow_package_share_dir"
    fi
}    

config_decl_set_package_name () {
    (( $# == 1 )) || fail "$FUNCNAME requires one parameter \$package-name (got $# args)"
    [[ is-set != "${config_package_name+is-set}" ]] || fail "$FUNCNAME can only be called once" 
    config_package_name="$1"
    config_decl_set CONFIG_PACKAGE_NAME "$config_package_name"
    config_set_shared
}

config_decl_set_prefix () {
    (( $# == 1 )) || fail "$FUNCNAME requires one parameter \$prefix (got $# args)"
    [[ is-set != ${config_prefix+is-set} ]] || fail "$FUNCNAME can only be called once"
    [[ -d $(dirname "$1") ]] || fail "parent dir of \$prefix must exist"
    [[ $1 != */ ]] || fail "\$prefix must not end in /"
    config_prefix=$(cd "$(dirname "$1")"; pwd)/$(basename "$1")
    [[ $config_prefix != */ ]] || fail "\$prefix must not end in /"
    config_decl_set CONFIG_PREFIX "$config_prefix"
    config_stow_packages_dir="$config_prefix/stow"
    config_decl_set CONFIG_STOW_PACKAGES_DIR "$config_stow_packages_dir"
    config_bin_dir="$config_prefix/bin"
    config_decl_set CONFIG_BIN_DIR "$config_bin_dir"
    config_set_shared
}

config_decl_set () {
    (( $# == 2 )) || fail "$FUNCNAME requires 2 args (got $#)"
    local macro="$1" value="$2"
    printf "%s: %s -> \"%s\"\n" "$0" "$macro" "$value" >&2
cat <<EOF >> "$config_decls_m4"
m4_define([[[$1]]],[[[$2]]])m4_dnl
EOF
}

config_decl_set_command () {
    (( $# >= 2 )) || fail "$FUNCNAME needs >= 2 args: macro, paths... (got $#)"
    local MACRO="$1"
    shift
    local OPTIONS=( $* )
    local COMMAND_PATH
    unset COMMAND_PATH
    while (( $# > 0 ))
    do if COMMAND_PATH=$(type -p "$1")
        then break
        else unset COMMAND_PATH
            shift
        fi
    done

    if [[ is-set = ${COMMAND_PATH+is-set} ]]
    then config_decl_set "$MACRO" "$COMMAND_PATH"
    else fail "executable for macro \"$MACRO\" not found (options were: ${OPTIONS[*]})"
    fi
}

config_decl_set_dir () {
    (( $# == 2 )) || fail "$FUNCNAME takes 2 args: macro, directory (got $#)"
    local MACRO="$1"
    local DIRECTORY="$2"
    [[ -d "$DIRECTORY" ]] || fail "directory does not exist ($DIRECTORY)"
    config_decl_set "$MACRO" "$DIRECTORY"
}

config_decl_set_file () {
    (( $# == 2 )) || fail "$FUNCNAME takes 2 args: macro, file name (got $#)"
    local MACRO="$1"
    local FILE="$2"
    [[ -f "$FILE" ]] || fail "file does not exist ($FILE)"
    config_decl_set "$MACRO" "$FILE"
}

config_end () {
    chmod uog-w "$config_decls_m4"
}

rm -f "$config_decls_m4"
cat <<EOF > "$config_decls_m4"
m4_changequote([[[,]]])m4_dnl
m4_changecom(,)m4_dnl
EOF

config_decl_set CONFIG_DECLS_M4 "$config_decls_m4"

trap config_end 0


