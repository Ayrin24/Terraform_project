resource "yandex_container_registry" "main" {
  name      = "shvirtd-registry"
  folder_id = var.folder_id
}

resource "yandex_container_repository" "webapp" {
  name = "${yandex_container_registry.main.id}/webapp"
}
