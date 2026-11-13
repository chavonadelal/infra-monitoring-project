# Infra Monitoring Project

Проект по заданию: мониторинг API, анализ логов, Docker Compose,
GitHub Actions и анализ HTTP-трафика.

## Что нужно для запуска

Git, Bash, curl, awk, grep, sed, sort, uniq и Docker Compose.
На Windows используются Git Bash и Docker Desktop с Linux-контейнерами.
Для просмотра дампа нужен Wireshark.

## Запуск проекта

```bash
git clone --branch feature/monitoring https://github.com/chavonadelal/infra-monitoring-project.git
cd infra-monitoring-project
chmod +x check_api.sh analyze_logs.sh
docker compose up -d
docker compose ps
curl http://localhost:80
# Monitoring Service Active
```

`docker-compose up -d` и `docker-compose ps` - эквивалентные команды,
если установлен отдельный исполняемый файл `docker-compose`.
В PowerShell для HTTP-запроса используйте `curl.exe`.

## Bash-скрипты

`check_api.sh` принимает один HTTP/HTTPS URL. При коде 200 выводит
«API доступен» и возвращает 0. При другом коде или ошибке возвращает 1.

```bash
./check_api.sh https://httpbin.org/status/200
echo "Код возврата: $?"
./check_api.sh https://httpbin.org/status/404
echo "Код возврата: $?"
./check_api.sh not-a-url
echo "Код возврата: $?"
```

`analyze_logs.sh` создаёт тестовый `access.log` из 360 строк, если файла нет,
и выводит общее количество запросов, топ-3 IP и количество ответов 4xx/5xx.
Используются регулярное выражение для IPv4 и команды grep, awk, sed, sort, uniq.

```bash
./analyze_logs.sh
./analyze_logs.sh --generate  # Заново создать тестовый access.log
```

Ожидается 360 запросов: топ IP - 192.168.1.10 (120), 10.0.0.5 (90),
172.16.0.3 (60); ответы 4xx - 72, ответы 5xx - 72.
Логи и временные файлы исключены из Git.

## Docker Compose

- `api`: готовый образ `hashicorp/http-echo:1.0.0`, порт 8080,
  ответ `Monitoring Service Active`.
- `proxy`: `nginx:alpine`, порт 80 на машине, проксирование на `api:8080`.
- Оба сервиса подключены к bridge-сети `monitoring`.
- Healthcheck Nginx проверяет ответ API через прокси.

Остановка: `docker compose down`.

## Git и CI

Работа ведётся в `feature/monitoring`. Ветка `main` защищена;
изменения проходят через [Pull Request № 1](https://github.com/chavonadelal/infra-monitoring-project/pull/1)
с успешной проверкой `Bash checks`.

GitHub Actions запускается при создании и обновлении PR в `main`.
Выполняются только проверки из задания:

```bash
bash -n check_api.sh
bash -n analyze_logs.sh
./check_api.sh https://httpbin.org/status/200
```

Последняя команда должна завершиться с кодом 0.

## Отчёт и сетевой трафик

- [PDF-отчёт](docs/report.pdf).
- [Дамп HTTP-трафика](docs/evidence/http-traffic.pcapng), также вложенный в PDF.
- [Скриншоты и вывод команд](docs/evidence/).

Дамп снят tcpdump на `eth0` временного контейнера Docker Desktop
с фильтром `tcp port 80`, затем открыт в Wireshark с фильтром `http`.
В нём 42 пакета, из них 8 HTTP: запросы GET/POST к httpbin.org
и ответы 200, 404, 503. IP клиента в сети Docker - 172.17.0.2,
IP сервера на момент захвата - 54.172.45.38.

## Передача проекта через SSH и SCP

Пример для Linux-сервера. Адрес `deploy@example.org` замените своим.
При генерации ключа задайте парольную фразу; перед первым подключением
проверьте отпечаток ключа сервера. Приватный ключ не передаётся на сервер.

```bash
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/infra_monitoring
ssh-copy-id -i ~/.ssh/infra_monitoring.pub deploy@example.org
ssh -i ~/.ssh/infra_monitoring deploy@example.org 'mkdir -p ~/infra-monitoring-project'
git archive --format=tar.gz -o ../project.tar.gz HEAD
scp -i ~/.ssh/infra_monitoring ../project.tar.gz deploy@example.org:~/infra-monitoring-project/
ssh -i ~/.ssh/infra_monitoring deploy@example.org \
  'cd ~/infra-monitoring-project && tar -xzf project.tar.gz && docker compose up -d && curl --fail http://localhost:80'
```

По заданию приведены команды деплоя; передача на реальный сервер не выполнялась.
