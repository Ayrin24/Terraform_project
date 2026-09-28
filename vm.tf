data "yandex_iam_service_account" "vm_sa" {
  name = var.vm_sa_name
}
resource "yandex_compute_instance" "app" {
  name        = "app-vm"
  hostname    = "app-vm"
  platform_id = "standard-v3"
  zone        = var.default_zone

  service_account_id = data.yandex_iam_service_account.vm_sa.id

  scheduling_policy {
    preemptible = true
  }

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = "fd8g39rqnaa88u265oic"
      size     = 10
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.develop.id
    security_group_ids = [yandex_vpc_security_group.example.id]
    nat                = true
  }

 metadata = {
   ssh-keys  = "ubuntu:${local.ssh_public_key}"
   user-data = templatefile("${path.module}/cloud-init.yaml", {
     registry_id = var.registry_id
     mysql_host  = var.mysql_host
     db_password      = var.db_password
     # Читаем key.json и передаём его содержимое
     key_json_base64  = base64encode(file(var.sa_key_file))
   })
 }
}
