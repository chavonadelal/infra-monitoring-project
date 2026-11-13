# Infra Monitoring Project

Учебный DevOps-проект: проверка HTTP API, анализ access-логов, два готовых
Docker-образа, GitHub Actions и исследование реального HTTP-трафика.

## Требования

- Bash 4+, curl, awk, grep, sed, sort, uniq, mktemp.
- Git, Docker Engine / Docker Desktop с Linux-контейнерами, Docker Compose v2.
- Python 3 для автоматических тестов; Wireshark для просмотра дампа.
- На Windows: Git Bash для скриптов, запущенный Docker Desktop.

## Быстрый запуск

```bash
git clone --branch feature/monitoring https://github.com/chavonadelal/infra-monitoring-project.git
cd infra-monitoring-project
chmod +x check_api.sh analyze_logs.sh
docker compose config --quiet
docker compose up -d --wait --wait-timeout 90
docker compose ps
curl --fail http://localhost:80
# Monitoring Service Active
./check_api.sh http://localhost:80
./analyze_logs.sh
```

`docker-compose up -d` и `docker-compose ps` - варианты написания из задания,
если установлен отдельный исполняемый файл `docker-compose`. В Compose v2
основная форма - `docker compose`. Порт 80 должен быть свободен.

На Windows в PowerShell используйте `curl.exe`, чтобы не вызвать одноимённый alias.

## Мониторинг API

```bash
./check_api.sh https://httpbin.org/status/200
echo "Код возврата: $?"   # API доступен; 0
./check_api.sh https://httpbin.org/status/404
echo "Код возврата: $?"   # API недоступен, код ответа: 404; 1
./check_api.sh not-a-url
echo "Код возврата: $?"   # Некорректный URL; 1
```

Принимается ровно один HTTP/HTTPS URL. Только HTTP 200 означает успех.
Перенаправления не выполняются. Таймаут подключения - 5 секунд, всего запроса -
15 секунд. При сетевом сбое выводится `000`, код завершения curl и диагностика
в stderr. Скрипт возвращает `1` при любой ошибке. Доступность публичного httpbin
зависит от внешней сети; независимые локальные тесты проверяют поведение скрипта.

## Анализ логов

```bash
./analyze_logs.sh                  # Создаёт access.log, если его ещё нет
./analyze_logs.sh --generate       # Явно перезаписывает тестовый access.log
./analyze_logs.sh existing.log     # Анализирует существующий файл
./analyze_logs.sh --generate demo.log
```

Генератор создаёт 360 воспроизводимых строк с GET/POST, шестью IP и кодами
200/201/401/404/500/503. Ожидаемый результат:

```text
Общее количество запросов: 360
Топ-3 IP-адреса (запросы IP):
120 192.168.1.10
90 10.0.0.5
60 172.16.0.3
Запросов с кодами 4xx: 72
Запросов с кодами 5xx: 72
```

Формат соответствует заданию: `IP - - [дата] "МЕТОД путь HTTP/1.1" код`.
Регулярное выражение проверяет IPv4 с октетами 0-255 и структуру записи;
неподходящие строки исключаются. Это парсер учебного формата, а не всех
вариантов combined access log. `sed` нормализует CRLF, `grep` отбирает записи,
`awk` считает запросы и ошибки, `sort | uniq -c | sort` строит топ IP.
При одинаковом числе запросов IP сортируются лексикографически.
Логи и временные файлы исключены из Git.

## Контейнеры

```text
curl localhost:80 -> proxy (nginx:alpine) -> api:8080 (hashicorp/http-echo:1.0.0)
```

Оба контейнера находятся в отдельной bridge-сети `monitoring`.
`api` слушает 8080 внутри сети, наружу публикуется только порт 80 Nginx.
Конфигурация прокси подключена read-only. Healthcheck прокси проверяет точный
текст ответа и тем самым доступность всей цепочки. `depends_on` задаёт порядок
старта, а `up --wait` дожидается успешного healthcheck.

```bash
docker compose logs --tail=50
docker compose exec proxy nginx -t
docker compose down
```

Используются готовые образы Docker Hub, сборка собственного образа не требуется.
Тег API закреплён; `nginx:alpine` оставлен согласно условию задания.

## Git Workflow и CI

Защищённая ветка `main` содержит стартовый коммит. Вся реализация находится
в `feature/monitoring`; PR предназначен для проверки и оставлен открытым.
В `main` изменения проходят через PR с успешной проверкой `Bash and Compose checks`.

Workflow `.github/workflows/ci.yml` запускается на PR в `main` и вручную:

1. `bash -n check_api.sh` и `bash -n analyze_logs.sh`.
2. Пять локальных тестов: HTTP 200/404/302, ошибки аргументов и соединения,
   генерация 360 строк, произвольный лог, некорректный IP и пустой файл.
3. `./check_api.sh https://httpbin.org/status/200` с ожидаемым exit code 0.
4. Проверка Compose, запуск контейнеров и запрос через Nginx.
5. Остановка контейнеров независимо от результата.

Локальная проверка на Linux:

```bash
bash -n check_api.sh
bash -n analyze_logs.sh
python3 -m unittest discover -s tests -v
```

В Windows для тестов укажите `BASH_EXECUTABLE` на `C:\Program Files\Git\bin\bash.exe`
и запускайте их доступным Python 3. Git хранит исполняемый бит обоих скриптов,
а `.gitattributes` обеспечивает LF для Bash.

## Анализ сетевого трафика и отчёт

Материалы сдачи будут доступны в `docs/`: PDF-отчёт, реальный дамп `.pcapng`,
скриншоты Wireshark, терминала и успешного GitHub Actions.
Тестовые HTTP-запросы не содержат ключей, cookies или личных данных.

При ручном повторении на рабочей станции:

1. Установите Wireshark с [официального сайта](https://www.wireshark.org/download.html)
   и Npcap для захвата Windows-интерфейсов.
2. Выберите используемый сетевой интерфейс, запустите захват с capture filter
   `tcp port 80`.
3. Выполните запросы `curl http://httpbin.org/get`,
   `curl -X POST -d 'assignment=monitoring' http://httpbin.org/post`,
   `curl http://httpbin.org/status/404`.
4. Остановите захват, установите display filter `http` и сохраните `.pcapng`.
5. По полям `ip.src`, `ip.dst`, `http.request.method`, `http.response.code`
   определите участников и результаты обмена.

В HTTPS HTTP-методы и коды зашифрованы; фильтр `tls` показывает TLS, но не
раскрывает HTTP. Поэтому для учебного анализа методов и кодов используется HTTP.

## Безопасная передача через SSH/SCP

Команды ниже - пример для Linux-сервера. Замените `deploy@example.org` своим
адресом. Реальная передача на удалённый сервер в задании не требуется.

```bash
# Отдельный ключ с парольной фразой; приватный ключ никогда не коммитить.
ssh-keygen -t ed25519 -a 100 -C "infra-monitoring-deploy" -f ~/.ssh/infra_monitoring

# Убедитесь в подлинности fingerprint сервера по независимому каналу.
ssh-copy-id -i ~/.ssh/infra_monitoring.pub deploy@example.org
ssh -i ~/.ssh/infra_monitoring deploy@example.org 'mkdir -p ~/infra-monitoring-project'

# Архив содержит только отслеживаемые файлы текущего коммита.
git archive --format=tar.gz --output=../infra-monitoring-project.tar.gz HEAD
scp -i ~/.ssh/infra_monitoring ../infra-monitoring-project.tar.gz \
  deploy@example.org:~/infra-monitoring-project/

ssh -i ~/.ssh/infra_monitoring deploy@example.org \
  'cd ~/infra-monitoring-project && tar -xzf infra-monitoring-project.tar.gz && docker compose up -d --wait && curl --fail http://localhost:80'
```

Альтернатива без промежуточного архива:

```bash
git archive --format=tar HEAD | ssh -i ~/.ssh/infra_monitoring deploy@example.org \
  'mkdir -p ~/infra-monitoring-project && tar -xf - -C ~/infra-monitoring-project'
```

Не отключайте проверку ключа хоста через `StrictHostKeyChecking=no`.
Используйте непривилегированного пользователя; доступ к Docker выдавайте
осознанно, поскольку управление Docker даёт широкие права на сервере.
Windows без `ssh-copy-id`: передайте только `.pub` администратору сервера либо
добавьте его в `~/.ssh/authorized_keys` через уже доверенный SSH-сеанс.
