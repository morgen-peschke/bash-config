#!/usr/bin/env bash
set -Eeuo pipefail

__curl.process-data-argument() {
    if [[ '-' = "$1" ]]; then
        printf '%s' '"<stdin>"'
    elif [[ $(cut -c1 <<<"$1") = '@' ]]; then
        jq --compact-output --raw-input 'try fromjson catch .' "$(cut -c2- "$1")"
    else
        jq --compact-output --raw-input 'try fromjson catch .' <<<"$1"
    fi
}

__curl.extractBody() {
    data=()
    while [[ -n "${1:-}" ]]; do
        case "$1" in
        --json | --data | -d | --data-ascii | --data-binary | --data-urlencode)
            shift
            data+=("$(__curl.process-data-argument "$1")")
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

__curl() {
    local expectJson includeKeys response responseLines status body keys lastHeaderLine rawHeaders headers bodyArg keysArg reqSummary requestId requestBody
    requestId=$(uuidgen | tr A-Z a-z | tr -d '\n')
    expectJson="$1"
    shift
    includeKeys="$1"
    shift
    requestBody=$(__curl.extractBody "$@")
    response=$(curl --silent --show-error -H "X-Request-Id=${requestId}" -iw '\n%{json}\n' "$@" >&1 || true)
    responseLines=$(jq --slurp --raw-input 'gsub("\r\n";"\n")|split("\n")' <<<"$response")
    status=$(jq '.[0] | if . == "" then null else . end' <<<"$responseLines")
    body=$(jq --compact-output --raw-output '.[-3] | if . == "" then null else . end' <<<"$responseLines")
    keys=$(jq --compact-output '.[-2] | fromjson' <<<"$responseLines")
    lastHeaderLine=$(jq --raw-output --compact-output '.num_headers | tonumber | . + 1' <<<"$keys")
    rawHeaders=$(jq --argjson lastHeaderLine "$lastHeaderLine" '.[1:$lastHeaderLine]' <<<"$responseLines")
    headers=$(jq 'map(split(":") | {key: .[0], value: .[1:]|join(":")|ltrimstr(" ")} ) | from_entries' <<<"$rawHeaders")

    reqSummary=$(jq --null-input \
        --argjson keys "$keys" \
        --argjson body "$requestBody" \
        '{ method: $keys.method, url: $keys.url, body: $body}')

    if [[ "$expectJson" = 'true' ]]; then
        bodyArg=(--argjson body "$body")
    else
        bodyArg=(--arg body "$body")
    fi
    if [[ "$includeKeys" = 'true' ]]; then
        keysArg="$keys"
    else
        keysArg=null
    fi

    result=$(jq --null-input \
        "${bodyArg[@]}" \
        --argjson keys "$keysArg" \
        --argjson headers "$headers" \
        --argjson status "$status" \
        --argjson request "$reqSummary" \
        --arg requestId "$requestId" \
        '{request: $request, requestId: $requestId, status: $status, keys: $keys, headers: $headers, body: $body}' 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        printf '%s\n' "$result"
    else
        jq >&2 --null-input \
            --arg body "$body" \
            --argjson keys "$keysArg" \
            --argjson headers "$rawHeaders" \
            --argjson status "$status" \
            --argjson request "$reqSummary" \
            --arg requestId "$requestId" \
            '{request: $request, requestId: $requestId, status: $status, keys: $keys, headers: $headers, body: $body}'
        printf '%s\n' '{}'
    fi
}

__curl "$@"
