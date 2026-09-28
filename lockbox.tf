resource "yandex_lockbox_secret" "db" {
  name      = "mysql-app-password"
  folder_id = var.folder_id
}

resource "yandex_lockbox_secret_version" "db" {
  secret_id = yandex_lockbox_secret.db.id
  entries {
    key        = "db_password"
    text_value = var.db_password
  }
}
