data "yandex_lockbox_secret_version" "db" {
  secret_id = yandex_lockbox_secret.db.id
}
