# Доказательства выполнения

- `wireshark-http.png`: настоящий скриншот Wireshark 4.6.9 с display filter `http`.
- `ci-success.jpg`: скриншот успешного GitHub Actions с проверками из задания,
  запуск 43434136479, коммит d2bd6f7.
- `http-traffic.pcapng`: дамп из 42 Ethernet-пакетов; 8 пакетов распознаны как HTTP.
- `api-output.txt`, `logs-output.txt`: фактический вывод Bash-скриптов.
- `docker-output.txt`: фактический вывод `docker-compose ps`.
- `docker-compose-ps.png`: настоящий скриншот терминала с `docker-compose ps`,
  выбранными столбцами Service/Image/Status, ответом API и проверкой Nginx.

SHA-256 дампа:
`154906d7045b108bd9030fbd65bd4efa1258c911437c98dbcc2daaabde3b7aca`.
