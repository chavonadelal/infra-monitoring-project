#!/usr/bin/env bash
set -uo pipefail

if [[ $# -ne 1 || ! $1 =~ ^https?://[^[:space:]]+$ ]]; then
    printf 'Использование: %s http[s]://адрес/api\n' "$0" >&2
    printf 'API недоступен, код ответа: 000 (некорректный URL)\n'
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    printf 'API недоступен, код ответа: 000 (curl не установлен)\n' >&2
    exit 1
fi

# Do not use --fail: HTTP errors must keep their actual response code.
# Do not follow redirects: the supplied endpoint itself must return 200.
code=$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' \
    --connect-timeout 5 --max-time 15 --proto '=http,https' -- "$1")
curl_status=$?

if [[ $curl_status -eq 0 && $code == 200 ]]; then
    printf 'API доступен\n'
    exit 0
fi

printf 'API недоступен, код ответа: %s\n' "${code:-000}"
if [[ $curl_status -ne 0 ]]; then
    printf 'Ошибка curl: %s\n' "$curl_status" >&2
fi
exit 1
