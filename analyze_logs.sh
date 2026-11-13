#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

usage() {
    printf 'Использование: %s [файл.log] | --generate [файл.log]\n' "$0" >&2
    exit 1
}

generate=false
case $# in
    0) logfile=access.log; [[ -e $logfile ]] || generate=true ;;
    1) if [[ $1 == --generate ]]; then generate=true; logfile=access.log
       elif [[ $1 == -* ]]; then usage
       else logfile=$1; fi ;;
    2) [[ $1 == --generate ]] || usage; generate=true; logfile=$2 ;;
    *) usage ;;
esac

if $generate; then
    # Reproducible 360-line fixture: known IP distribution and 72 errors per class.
    awk 'BEGIN {
        split("200 201 200 404 401 500 503 200 200 200", codes, " ")
        for (i=1; i<=360; i++) {
            if (i<=120) ip="192.168.1.10"
            else if (i<=210) ip="10.0.0.5"
            else if (i<=270) ip="172.16.0.3"
            else if (i<=315) ip="192.168.1.20"
            else if (i<=345) ip="10.0.0.8"
            else ip="172.16.0.9"
            method=(i%3==0 ? "POST" : "GET")
            path=(method=="POST" ? "/api/login" : "/api/users")
            printf "%s - - [15/Aug/2026:10:%02d:%02d] \"%s %s HTTP/1.1\" %s\n", \
                ip, int((i-1)/60), (i-1)%60, method, path, codes[(i-1)%10+1]
        }
    }' > "$logfile"
    printf 'Создан тестовый файл: %s (360 строк)\n' "$logfile"
fi

if [[ ! -f $logfile || ! -r $logfile ]]; then
    printf 'Ошибка: файл недоступен: %s\n' "$logfile" >&2
    exit 1
fi

parsed=$(mktemp)
trap 'rm -f -- "$parsed"' EXIT
# Strict IPv4 octets, including boundaries: 999.1.1.1 is not an IP.
octet='(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])'
ip_regex="${octet}(\.${octet}){3}"
record_regex="^${ip_regex} - - \[[^]]+\] \"(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS) [^\"]+ HTTP/[0-9.]+\" [1-5][0-9]{2}$"
# Normalize CRLF files as well as Linux LF files; ignore malformed records.
if sed 's/\r$//' "$logfile" | grep -E "$record_regex" > "$parsed"; then
    :
else
    status=$?
    [[ $status -eq 1 ]] || exit "$status"
fi

printf 'Общее количество запросов: '
awk 'END {print NR+0}' "$parsed"
printf 'Топ-3 IP-адреса (запросы IP):\n'
awk '{print $1}' "$parsed" | sort | uniq -c | sort -k1,1nr -k2,2 | awk 'NR<=3 {printf "%d %s\n", $1, $2}'
awk '$NF ~ /^4[0-9]{2}$/ {client++} $NF ~ /^5[0-9]{2}$/ {server++}
    END {printf "Запросов с кодами 4xx: %d\nЗапросов с кодами 5xx: %d\n", client+0, server+0}' "$parsed"
