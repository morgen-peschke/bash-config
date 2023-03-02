#!/usr/bin/env bash
set -Eeuo pipefail
#set -x

args.process-data-argument() {
    if [[ '-' = "$1" ]]; then
        printf '%s' '"<stdin>"'
    elif [[ $(cut -c1 <<<"$1") = '@' ]]; then
        jq --compact-output --raw-input 'try fromjson catch .' "$(cut -c2- "$1")"
    else
        jq --compact-output --raw-input 'try fromjson catch .' <<<"$1"
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
    local responseLines="$1"
    local rawBody parsedBody
    rawBody=$(extract.line -3 "$responseLines")
    jq <<<"$rawBody" --compact-output \
        '{raw: ., parsed: (try fromjson catch .)}'
}

__curl() {
    local curlArgs includeKeys responseLines status body keys rawHeaders headers keysArg reqSummary requestId requestBody
    requestId="morgen-$(uuidgen | tr A-Z a-z | tr -d '\n')"
    includeKeys="$1"
    shift
    requestBody=$(args.extract.requestBody "$@")
    curlArgs=(--silent --show-error -H "X-Request-Id: ${requestId}" -iw '\n%{json}\n' "$@")
    responseLines=$(curl.returningLines "${curlArgs[@]}")
    status=$(extract.line 0 "$responseLines")
    keys=$(extract.line -2 "$responseLines" raw)
    headers=$(response.extract.headers "$responseLines" "$keys")
    body=$(response.extract.body "$responseLines")
    reqSummary=$(output.build.summary "$keys" "$requestBody" "${curlArgs[@]}")

    if [[ "$includeKeys" = 'true' ]]; then
        keysArg="$keys"
    else
        keysArg=null
    fi

    result=$(jq --null-input \
        --argjson body "$body" \
        --argjson keys "$keysArg" \
        --argjson headers "$headers" \
        --argjson status "$status" \
        --argjson request "$reqSummary" \
        --arg requestId "$requestId" \
        '{request: $request, requestId: $requestId, status: $status, keys: $keys, headers: $headers.parsed, body: $body.parsed}' 2>/dev/null || true)
    if [[ $result ]]; then
        printf '%s\n' "$result"
    else
        jq >&2 --null-input \
            --argjson body "$body" \
            --argjson keys "$keysArg" \
            --argjson headers "$headers" \
            --argjson status "$status" \
            --argjson request "$reqSummary" \
            --arg requestId "$requestId" \
            '{request: $request, requestId: $requestId, status: $status, keys: $keys, headers: $headers, body: $body}'
        printf '%s\n' '{}'
    fi
}

__curl "$@"
