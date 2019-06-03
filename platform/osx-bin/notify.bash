#!/bin/bash

DEFAULT_TITLE='Hey! Listen!'
TITLE="$DEFAULT_TITLE"
LINK=
MESSAGE=

function args.help () {
    local error="$1"
    if [ "$error" ]; then
        echo >&2 "$error"
    fi
    cat >&2 <<EOF
Usage $0 <options>

Displays a message using an Applescript notification box

Options
-------

--title <text>    Sets the title, otherwise the default is used ("$DEFAULT_TITLE")
 -t     <text>    Alias for --title

--link  <url>     Add a button to open a link
 -l     <url>     Alias for --link

--body  <text>    Set the message body
 -m     <text>    Alias for --body
EOF
}

function args.verify-not-empty () {
    local value="$1"
    local varname="$2"

    if [ "$value" ]; then
        echo "$value"
    elif [ "$varname" ]; then
        args.help "$varname cannot handle an empty argument"
        exit 1
    else
        args.help \
            "The programmer forgot to include context, something was empty which shouldn't have been, but I can't tell you much more than that. Sorry :("
        exit 1
    fi
}

function args.parse () {
    while [ "$1" ]
    do
        case "$1" in
            '-t' | '--title')
                shift
                TITLE=$(args.verify-not-empty "$1" title)
                shift
                ;;
            '-l' | '--link')
                shift
                LINK=$(args.verify-not-empty "$1" link)
                shift
                ;;
            '-m' | '--body')
                shift
                if [[ "$1" = '-' ]]; then
                    MESSAGE=$(cat -)
                else
                    MESSAGE="$1"
                fi
                MESSAGE=$(args.verify-not-empty "$MESSAGE" body)
                shift
                ;;
            *)
                args.help "Unrecognized argument: $1"
                exit 1
        esac
    done
    if [[ ! "$MESSAGE" ]]; then
        args.help "Message body was not specified"
        exit 1
    fi
}

function message.display-no-link () {
    osascript > /dev/null <<EOF
tell application "Finder"
  activate
  display alert "$TITLE" ¬
          message "$MESSAGE" ¬
          buttons { "Acknowledge" } ¬
          default button "Acknowledge"
end tell
return
EOF
}

function message.display-with-link () {
    osascript > /dev/null <<EOF
tell application "Finder"
  activate
  display alert "$TITLE" ¬
          message "$MESSAGE\n\nClick 'Open Link' to go to $LINK" ¬
          buttons { "Acknowledge", "Open Link" } ¬
          default button "Open Link"
          set response to button returned of the result
          if response is "Open Link" then open location "$LINK"
end tell
return
EOF
}

function message.display () {
    if [ "$LINK" ]; then
        message.display-with-link
    else
        message.display-no-link
    fi
}

args.parse "$@"
message.display
