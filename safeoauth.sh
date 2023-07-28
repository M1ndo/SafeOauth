#!/usr/bin/env bash
# Written by ybenel on (2023/07/24)

# Check Dependencies.
function checkdeps() {
    # Define the list of commands to check
    depends=("gpg" "pass" "zenity" "oathtool" "xclip")
    # Define arrays to store the results
    found=()
    missing=()
    # Check if each command exists
    for cmd in "${depends[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            found+=("$cmd")
        else
            missing+=("$cmd")
        fi
    done
    echo "[+] Checking Dependencies."
    for cmd in "${found[@]}"; do
        echo "✔ $cmd"
    done
    if [ ${#missing[@]} -gt 0 ]; then
        echo "Some dependencies are missing, please install them."
        for cmd in "${missing[@]}"; do
            echo "✘ $cmd"
        done
        exit 1
    fi
}

# Check If Pass has already been settup.
function check_pass() {
    if [[ ! -d ~/.password-store/ ]]; then
        zenity --info --text "Password-store has not been initialized yet\nRun pass init 'gpg-uid' to do so."
        exit 1
    fi
}

# Entry Checker.
function check_entry() {
    if [[ -f ~/.password-store/$1.gpg ]]; then
        return 1
    else
        return 0
    fi
}

# Repeat Command Till Success
function cmd_rep() {
    local output=$($1)
    local ret=$2
    if [[ "failed" =~ $output ]]; then
        code=2
    else
        code=0
    fi
    if [[ $code -eq 0 ]]; then
        eval "$ret=\"$output\""
    else
        cmd_rep "$1" "$ret"
    fi
}

# Create new otp key
function otp_new() {
    IFS='|' read -ra name_secret <<< $(zenity --entry --title "New OTP Entry" --text "Enter name|secret" --width=300 --height=100)
    name=${name_secret[0]}
    secret=${name_secret[1]}
    while true; do
        check_entry "$name"
        ret=$?
        if [[ $ret -eq 1 ]]; then
            zenity --error --title "[!] Error" --text "Name <b>$name</b> Already Exists\nClick OK to change the name"
            while true; do
                new_name=$(zenity --entry --title "Insert new name" --text "Insert a new name")
                check_entry "$new_name"
                var=$?
                if [[ $var -eq 0 ]]; then
                    name="$new_name"
                    break 2
                else
                    zenity --error --title "[!] Error" --text "Name <b>$new_name</b> Already Exists\nClick OK to enter a new name"
                fi
            done
        else
            break
        fi
    done
    if [[ -z "$name" || -z "$secret" ]]; then
        zenity --error --text "Name or secret has been set." && exit 1
    fi
    pass generate "$name" >/dev/null
    (echo $secret; echo $secret) | pass insert $name
    echo $name >> $HOME/.config/.safeoauth.lst
}

# OTP Show
function otp_show() {
    filename="$HOME/.config/.safeoauth.lst"
    names=($(cat "$filename"))
    selected_name=$(zenity --list --height=300 --width=150 --title "Select an entry" --text "Select an entry from below" --column "Name" "${names[@]}")
    if [[ -n "$selected_name" ]]; then
        cmd_rep "pass show $selected_name" key
        key=$(oathtool -b --totp $key)
        cp=$(zenity --info --extra-button="Copy" --icon-name 'dialog-password' --text "Your Key:\n <b>$key</b>")
        if [[ -n $cp ]]; then
            echo $key | xclip -sel clipboard -rmlastnl
        fi
    fi
}

# OTP Edit
function otp_edit() {
    filename="$HOME/.config/.safeoauth.lst"
    names=($(cat "$filename"))
    selected_name=$(zenity --list --height=300 --width=150 --title "Select an entry" --text "Select an entry to edit" --column "Name" "${names[@]}")
    if [[ -n "$selected_name" ]]; then
        new_key=$(zenity --entry --height=300 --width=150 --text "Enter new key for $selected_name")
        cmd_rep "pass show $selected_name" key
        zenity --question --text "Are you sure you want to replace <b>$key</b> with <b>$new_key</b>."
        confirm=$?
        if [[ $confirm -eq 0 ]]; then
            (echo $new_key; echo $new_key) | pass insert $selected_name
            echo "Entry: $selected_name :: new_key: $new_key :: old_key: $key" >> $HOME/.config/.safeoauth.backup
        else
            zenity --info --text "You have chosen to cancel the editing." --timeout 10
        fi
    fi
}

checkdeps
check_pass
shortopts="cshe"
longopts=$(getopt -o $shortopts --long create,show,edit,help -- "$@")
eval set -- "$longopts"
while true; do
    case $1 in
        -c|--create) otp_new;;
        -s|--show) otp_show;;
        -e|--edit) otp_edit;;
        -h|--help)
            echo "Usage: $0 [-c|--create] [-s|--show] [-h|--help]" >&2
            exit 1 ;;
        --)shift; break;;
        *) echo "Invalid option: $1" >&2
           exit 1;;
    esac
    shift
done
