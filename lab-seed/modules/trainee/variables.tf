variable "counter" {
  description = "Numer porządkowy uczestnika w tym batchu (1, 2, 3, ...)."
  type        = number
}

variable "batch_suffix" {
  description = "Losowy 4-znakowy sufiks wspólny dla całego batcha — odróżnia loginy z tego uruchomienia od innych."
  type        = string
}

variable "tenant_domain" {
  description = "Domena Entra ID używana do budowy UPN uczestnika."
  type        = string
}

variable "location" {
  description = "Region Azure dla grupy zasobów uczestnika."
  type        = string
}

variable "group_object_id" {
  description = "Object ID grupy Entra ID uczestników — dostaje rolę Reader na tej grupie zasobów."
  type        = string
}
