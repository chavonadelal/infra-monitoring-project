# Доказательства выполнения

- `wireshark-http.png`: настоящий скриншот Wireshark 4.6.9 с display filter `http`.
- `ci-success.jpg`: настоящий скриншот успешного первого CI, run 43425871215,
  commit bc4176d. После добавления демонстрационных шагов успешен также run
  43427063415, commit bfe2c58; его результат сохранён в `ci-result.json`.
- `http-traffic.pcapng`: 42 реальных Ethernet-пакета, снятых tcpdump на eth0
  временного Docker-контейнера. 8 пакетов распознаны как HTTP.
- `http-summary.csv`: поля HTTP, извлечённые tshark из дампа.
- `capture-output.txt`: фактический протокол захвата и HTTP-коды curl.
- `api-output.txt`, `logs-output.txt`: фактический вывод Bash-скриптов.
- `docker-output.txt`, `docker-compact.txt`: фактический `docker-compose ps`.
- `docker-compose-ps.png`: настоящий скриншот терминала с `docker-compose ps`,
  выбранными столбцами Service/Image/Status, ответом API и проверкой Nginx.

SHA-256 дампа:
`154906d7045b108bd9030fbd65bd4efa1258c911437c98dbcc2daaabde3b7aca`.
