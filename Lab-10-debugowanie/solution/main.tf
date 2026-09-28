resource "local_file" "greeting" {
  filename = "${path.module}/greeting.txt"
  content  = "Cześć, ${var.name}! To Twój pierwszy zasób Terraform.\n"
}
