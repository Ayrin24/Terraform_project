# Итоговый проект: Развертывание инфраструктуры в Yandex Cloud связный репозиторий и образ + https://github.com/Ayrin24/bootstrap-.git + образ там же в архиве

Развертывание полноценной инфраструктуры в Yandex Cloud с помощью Terraform: VPC, подсеть, виртуальная машина, MySQL-кластер, Container Registry и Lockbox. Docker и Docker Compose устанавливаются через `cloud-init`, web-приложение запускается из Container Registry и подключается к управляемой БД.

## 📋 Содержание

- [Архитектура](#архитектура)
- [Структура проекта](#структура-проекта)
- [Требования](#требования)
- [Развертывание](#развертывание)
- [Проверка работоспособности](#проверка-работоспособности)
- [Переменные](#переменные)
- [Проблемы и решения](#проблемы-и-решения)
- [Удаление инфраструктуры](#удаление-инфраструктуры)

## 🏗 Архитектура

```
┌──────────────────────────────────────────────────────────────┐
│                       Yandex Cloud                            │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              VPC: develop (10.0.1.0/24)                  │ │
│  │                                                          │ │
│  │  ┌──────────────────┐       ┌───────────────────────┐   │ │
│  │  │    app-vm        │       │   MySQL Cluster       │   │ │
│  │  │  Ubuntu 22.04    │──────▶│   app-mysql           │   │ │
│  │  │                  │ :3306 │   БД: example         │   │ │
│  │  │  Docker +        │       │   Юзер: app           │   │ │
│  │  │  webapp:latest   │       └───────────────────────┘   │ │
│  │  │  :8090→:5000     │                                    │ │
│  │  └────────┬─────────┘                                    │ │
│  │           │ docker pull                                   │ │
│  │           ▼                                               │ │
│  │  ┌──────────────────┐       ┌───────────────────────┐   │ │
│  │  │ Container        │       │   Lockbox Secret      │   │ │
│  │  │ Registry         │       │   mysql-app-password  │   │ │
│  │  │ shvirtd-registry │       │   (db_password)       │   │ │
│  │  └──────────────────┘       └───────────────────────┘   │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                               │
│  Security Group: ingress 22 (SSH), 80 (HTTP), 443 (HTTPS)     │
│  Remote State: S3 bucket tfstate-bucket-mulenko (use_lockfile)│
└──────────────────────────────────────────────────────────────┘
```

## 📁 Структура проекта

```
.
├── backend.tf              # Remote state в S3 (Yandex Object Storage)
├── providers.tf            # Провайдер Yandex Cloud
├── variables.tf            # Входные переменные
├── locals.tf               # Локальные значения (SSH-ключ)
├── main.tf                 # VPC и подсеть
├── security.tf             # Группа безопасности (22, 80, 443)
├── vm.tf                   # Виртуальная машина + cloud-init
├── mysql.tf                # MySQL-кластер, БД, пользователь
├── registry.tf             # Container Registry и репозиторий
├── lockbox.tf              # Секрет Lockbox для пароля БД
├── lockbox_data.tf         # Data source для чтения секрета
├── cloud-init.yaml         # YAML cloud-config для ВМ
├── Dockerfile.python       # Мультистейдж-сборка приложения
├── requirements.txt        # Python-зависимости
├── .gitignore              # Исключения для git
└── README.md               # Этот файл
```

## ⚙️ Требования

- **Terraform** ≥ 1.15.0
- **Yandex Cloud CLI** (`yc`)
- **Docker** ≥ 20.10 (с BuildKit)
- **Сервисный аккаунт** Yandex Cloud с ролями:
  - `editor` — на каталог (или точечные роли на VPC, Compute, MDB, Registry)
  - `lockbox.payloadViewer` — на секрет Lockbox
  - `container-registry.images.puller` — для SA виртуальной машины
- **S3-бакет** для remote state (`tfstate-bucket-mulenko`)
- **SSH-ключ** для доступа к ВМ
- **`key.json`** — авторизованный ключ сервисного аккаунта

## 🚀 Развертывание

### 1. Настройка YC CLI

```bash
yc init
yc config set folder-id <FOLDER_ID>
```

### 2. Инициализация Terraform

```bash
terraform init
```

### 3. Сборка и публикация Docker-образа

**Важно:** для Yandex Container Registry используем BuildKit с отключёнными `provenance` и `sbom`, иначе registry вернёт `Cannot read manifest data`.

```bash
# Аутентификация
yc container registry configure-docker

# Сборка и публикация одной командой
docker buildx build \
  --provenance=false \
  --sbom=false \
  --push \
  -f Dockerfile.python \
  -t cr.yandex/<REGISTRY_ID>/webapp:latest \
  .
```

Проверка, что образ в реестре:

```bash
yc container image list --registry-id <REGISTRY_ID>
```

### 4. Применение конфигурации

```bash
terraform apply -var="db_password=*"
```

### 5. Получение IP-адреса ВМ

```bash
terraform output vm_external_ip
```

## ✅ Проверка работоспособности

### Подключение к ВМ

```bash
ssh ubuntu@<VM_EXTERNAL_IP>
```

### Проверка cloud-init

```bash
sudo cloud-init status --long
sudo tail -50 /var/log/cloud-init-output.log
```

Статус должен быть `done`. Если `error` — смотрите лог.

### Проверка Docker и приложения

```bash
sudo docker ps
sudo docker logs web
curl http://localhost:8090
```

Ожидаемый результат:
- `docker ps` показывает контейнер `web` в статусе `Up`, порт `0.0.0.0:8090->5000/tcp`
- `curl` возвращает HTML/JSON приложения

### Проверка из браузера

```
http://<VM_EXTERNAL_IP>:8090
```

### Проверка подключения к БД

```bash
sudo docker exec -it web sh

# внутри контейнера
python -c "
import mysql.connector
conn = mysql.connector.connect(
    host='<MYSQL_FQDN>',
    user='app',
    password='<DB_PASSWORD>',
    database='example'
)
print('Connected to MySQL!')
conn.close()
"
```

## 🔧 Переменные

| Переменная | Тип | Обязательная | По умолчанию | Описание |
|------------|-----|--------------|--------------|----------|
| `cloud_id` | string | да | — | ID облака Yandex Cloud |
| `folder_id` | string | да | — | ID каталога |
| `default_zone` | string | нет | `ru-central1-a` | Зона доступности |
| `default_cidr` | list(string) | нет | `["10.0.1.0/24"]` | CIDR подсети |
| `vpc_name` | string | нет | `develop` | Имя VPC |
| `sa_key_file` | string | нет | `/home/mulen/key.json` | Путь к ключу SA |
| `ssh_user` | string | нет | `mulenkois` | Имя SSH-пользователя |
| `db_password` | string | да | — | Пароль пользователя БД |
| `vm_sa_name` | string | нет | `mulenkois` | Имя SA для ВМ |
| `registry_id` | string | нет | `crpbu001cr8n89t1f5ua` | ID Container Registry |
| `mysql_host` | string | нет | `c-c9qbo3iv9u06cvj0bv4h.rw.mdb.yandexcloud.net` | FQDN MySQL |

## 🐛 Проблемы и решения

В ходе работы встретились следующие проблемы:

### 1. `yc: not found` в cloud-init

**Причина:** YC CLI не установлен на ВМ, а `cloud-init.yaml` пытался вызвать `yc container registry configure-docker`.

**Решение:** отказ от `yc` в пользу аутентификации через `key.json`:

```yaml
runcmd:
  - cat /opt/app/key.json | docker login --username json_key --password-stdin cr.yandex
```

### 2. `cannot perform an interactive login from a non TTY device`

**Причина:** `key.json` не был создан на ВМ (отсутствовал блок `write_files`), `cat` падал, `TOKEN`/`key.json` оказывались пустыми, Docker пытался запросить пароль интерактивно.

**Решение:** добавить `write_files` для `key.json` с явным `owner: root:root`.

### 3. `Failed loading yaml blob. Invalid format at line 10`

**Причина:** содержимое `key.json` (JSON с кавычками и скобками) подставлялось в YAML через `templatefile` без экранирования — YAML-парсер ломался.

**Решение:** кодировать `key.json` в base64 и декодировать на ВМ:

```hcl
# vm.tf
key_json_base64 = base64encode(file(var.sa_key_file))
```

```yaml
# cloud-init.yaml
- echo "${key_json_base64}" | base64 -d > /opt/app/key.json
```


### 4. `Cannot read manifest data` при `docker push`

**Причина:** BuildKit по умолчанию создаёт manifest list с attestation (provenance + SBOM), который Yandex Container Registry не понимает.

**Решение:** отключить provenance и SBOM:
```bash
docker buildx build \
  --provenance=false \
  --sbom=false \
  --push \
  -f Dockerfile.python \
  -t cr.yandex/<REGISTRY_ID>/webapp:latest \
  .
```

### 6. `exec: "uvicorn": executable file not found in $PATH`

**Причина:** мультистейдж-сборка через legacy builder (BuildKit отключён) некорректно копирует `/opt/venv` из builder-стадии в final.

**Решение:** убедиться, что BuildKit включён (`export DOCKER_BUILDKIT=1`), и явно указать файл `-f Dockerfile.python` (если мультистейдж-версия лежит в нём, а не в `Dockerfile`).

### 7. `Iteration over null value` при чтении Lockbox

**Причина:** data source `yandex_lockbox_secret_version` возвращает `entries = null`, если у SA Terraform нет роли `lockbox.payloadViewer` на секрет.

**Решение:** выдать роль:
```bash
yc lockbox secret add-access-binding <SECRET_ID> \
  --role lockbox.payloadViewer \
  --service-account-id <SA_ID>
```

## 🗑 Удаление инфраструктуры

```bash
# 1. Очистить Container Registry (иначе destroy упадёт)
yc container image list --registry-id <REGISTRY_ID>
yc container image delete <IMAGE_ID>

# 2. Удалить инфраструктуру
terraform destroy -var="db_password=VeryStrong123!"
```

## 📚 Полезные ссылки

- [Terraform Yandex Cloud](https://yandex.cloud/ru/docs/tutorials/infrastructure-management/terraform-quickstart)
- [Yandex Container Registry](https://yandex.cloud/ru/docs/container-registry/)
- [Аутентификация в Container Registry](https://yandex.cloud/ru/docs/container-registry/operations/authentication)
- [Yandex Lockbox](https://yandex.cloud/ru/docs/lockbox/)
- [Yandex MDB MySQL](https://yandex.cloud/ru/docs/managed-mysql/)
- [cloud-init документация](https://cloudinit.readthedocs.io/)
- [Docker buildx](https://docs.docker.com/build/building/multi-platform/)

## 👤 Автор

**Муленко И.С.** — итоговый проект

Скриншоты:

<img width="1215" height="193" alt="image" src="https://github.com/user-attachments/assets/b86a2069-c133-4a4a-87ac-d90082dbbeec" />

<img width="1418" height="846" alt="image" src="https://github.com/user-attachments/assets/17c8dc31-9888-44c2-a8da-505e5ea984dd" />

<img width="1213" height="134" alt="image" src="https://github.com/user-attachments/assets/29875625-38d2-4d78-9524-62ad95d5517c" />

<img width="755" height="498" alt="image" src="https://github.com/user-attachments/assets/4b352a01-9d53-4946-9007-641f2a0b83e1" />

