#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${TRACE-0}" == "1" ]]; then
    set -o xtrace
fi

source "$HOME/.bash-config/templates/cli-option.utils.bash"

# Define Options
INCLUDE_KEYS=false

declare -rA OPT_SHORT=()
declare -rA OPT_LONG=(
    [INCLUDE_KEYS]='--include-keys'
)
declare -rA OPT_METAVAR=()
declare -rA OPT_DESCRIPTION=(
    [INCLUDE_KEYS]='Include the raw keys provided by curl in the output'
)

cli.options.help() {
    printf 'Usage: %s [<options...>] -- <curl args...>\n\n' "$0"
    cli.options.help-text
}

cli.options.load "$@"

args.process-data-argument() {
    if [[ '-' = "$1" ]]; then
        printf '%s' '"<stdin>"'
    elif [[ $(cut -c1 <<<"$1") = '@' ]]; then
        jq --compact-output --raw-input --slurp 'fromjson? // .' "$(cut -c2- "$1")"
    else
        jq --compact-output --raw-input --slurp 'fromjson? // .' <<<"$1"
    fi
}

args.extract.requestBody() {
    data=()
    while [[ -n "${1:-}" ]]; do
        case "$1" in
        --json | --data | -d | --data-ascii | --data-binary | --data-urlencode)
            shift
            data+=("$(args.process-data-argument "$1")")
            shift
            ;;
        --data-raw | --form | -F | --form-string | --form-escape)
            shift
            data+=("$(jq --compact-output '.' <<<"$1")")
            shift
            ;;
        *)
            shift
            ;;
        esac
    done
    jq --null-input --compact-output '$ARGS.positional' --jsonargs "${data[@]}"
}

curl.returningLines() {
    local curlArgs=("$@")
    response=$(curl "${curlArgs[@]}" || true)
    jq --slurp --raw-input 'gsub("\r\n";"\n")|split("\n")' <<<"$response"
}

extract.line() {
    local lineNumber="${1:-0}" allLines="${2:-'[]'}" raw="${3:-}"
    local outputArg='--compact-output'
    [[ "$raw" = 'raw' ]] && outputArg='--raw-output'
    jq <<<"$allLines" \
        --argjson line "$lineNumber" \
        "$outputArg" \
        '.[$line] | if . == "" then null else . end'
}

output.build.summary() {
    local keys requestBody curlArgs
    keys="$1"
    shift
    requestBody="$1"
    shift
    curlArgs=("$@")
    jq --null-input \
        --argjson keys "$keys" \
        --argjson body "$requestBody" \
        '{ method: $keys.method, url: $keys.url, body: $body, curl: "curl \($ARGS.positional | @sh)"}' \
        --args -- "${curlArgs[@]}"
}

response.extract.headers() {
    local responseLines="$1" keys="$2"
    local lastHeaderLine rawHeaders headers
    lastHeaderLine=$(jq --raw-output --compact-output '.num_headers | tonumber | . + 1' <<<"$keys")
    rawHeaders=$(jq --compact-output --argjson lastHeaderLine "$lastHeaderLine" '.[1:$lastHeaderLine]' <<<"$responseLines")
    headers=$(jq --compact-output 'map(split(":") | {key: .[0], value: .[1:]|join(":")|ltrimstr(" ")} ) | from_entries' <<<"$rawHeaders")
    jq --compact-output --null-input \
        --argjson raw "$rawHeaders" \
        --argjson parsed "$headers" \
        '{raw: $raw, parsed: $parsed}'
}

response.extract.body() {
    local responseLines="$1" keys="$2"
    local rawBody firstBodyLine
    # See lastHeaderLine in response.extract.headers
    firstBodyLine=$(jq --raw-output --compact-output '.num_headers | tonumber | . + 2' <<<"$keys")
    rawBody=$(jq --compact-output --argjson firstBodyLine "$firstBodyLine" '.[$firstBodyLine:-2]' <<<"$responseLines")
    case "$rawBody" in
    'null')
        jq --null-input --compact-output '{raw: null, parsed: null }'
        ;;
    ''|'[]')
        jq --null-input --compact-output '{raw: "", parsed: null }'
        ;;
    *)
        jq <<<"$rawBody" --compact-output \
            '{
                raw: ., 
                parsed: (reduce .[] as $i (""; . + $i) | fromjson? // .)
            }'
        ;;
    esac
}

__curl() {
    local curlArgs responseLines status body keys rawHeaders headers keysArg reqSummary requestId requestBody before_ts after_ts
    requestId="morgen-$(uuidgen | tr A-Z a-z | tr -d '\n')"
    requestBody=$(args.extract.requestBody "$@")
    before_ts=$(jq --null-input 'now')
    curlArgs=(--silent --show-error -H "X-Request-Id: ${requestId}" "$@")
    responseLines=$(curl.returningLines -iw '\n%{json}\n' "${curlArgs[@]}")
    after_ts=$(jq --null-input 'now')
    status=$(extract.line 0 "$responseLines")
    keys=$(extract.line -2 "$responseLines" raw)
    headers=$(response.extract.headers "$responseLines" "$keys")
    body=$(response.extract.body "$responseLines" "$keys")
    reqSummary=$(output.build.summary "$keys" "$requestBody" "${curlArgs[@]}")

    if [[ "$INCLUDE_KEYS" = 'true' ]]; then
        keysArg="$keys"
    else
        keysArg='null'
    fi

    result=$(jq 2>/dev/null \
        --null-input \
        --argjson body "$body" \
        --argjson keys "$keysArg" \
        --argjson headers "$headers" \
        --argjson status "$status" \
        --argjson request "$reqSummary" \
        --argjson beforeTs "$before_ts" \
        --argjson afterTs "$after_ts" \
        --arg requestId "$requestId" \
        '{
            request: $request, 
            requestId: $requestId, 
            status: $status,
            timing: {
                beforeTs: $beforeTs,
                afterTs: $afterTs,
                durationCap_sec: ($afterTs - $beforeTs)
            },
            keys: $keys,
            headers: $headers.parsed, 
            body: ($body.parsed // $body.raw)
        }' || true)
    if [[ $result ]]; then
        printf '%s\n' "$result"
    else
        jq >&2 \
            --null-input \
            --argjson body "$body" \
            --argjson keys "$keysArg" \
            --argjson headers "$headers" \
            --argjson status "$status" \
            --argjson request "$reqSummary" \
            --arg requestId "$requestId" \
            --argjson lines "$responseLines" \
            '{
                request: $request, 
                requestId: $requestId, 
                status: $status, 
                keys: $keys, 
                headers: $headers, 
                body: $body,
                lines: $lines
            }'
        printf '%s\n' '{}'
    fi
}

__curl "${POSITIONAL[@]}"
