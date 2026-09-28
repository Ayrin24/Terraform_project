resource "yandex_mdb_mysql_cluster" "app" {
  name        = "app-mysql"
  environment = "PRESTABLE"
  network_id  = yandex_vpc_network.develop.id
  version     = "8.0"

  resources {
    resource_preset_id = "s2.micro"
    disk_type_id       = "network-ssd"
    disk_size          = 16
  }

  host {
    zone      = var.default_zone
    subnet_id = yandex_vpc_subnet.develop.id
  }
}

resource "yandex_mdb_mysql_database" "app" {
  cluster_id = yandex_mdb_mysql_cluster.app.id
  name       = "example"
}

resource "yandex_mdb_mysql_user" "app" {
  cluster_id = yandex_mdb_mysql_cluster.app.id
  name       = "app"
  password   = var.db_password

  permission {
    database_name = yandex_mdb_mysql_database.app.name
    roles         = ["ALL"]
  }
}
