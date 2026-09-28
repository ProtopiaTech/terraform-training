variable "resource_group_name" {
  description = "Nazwa grupy zasobów, w której powstaną zasoby modułu."
  type        = string
}

variable "location" {
  description = "Region Azure."
  type        = string
}

variable "name_prefix" {
  description = "Prefiks nazw zasobów (np. \"tftrain-agent-reports\") — moduł sam oczyszcza go do wymogów Storage Account."
  type        = string
}

variable "tags" {
  description = "Tagi do zastosowania na wszystkich zasobach modułu."
  type        = map(string)
  default     = {}
}

variable "account_tier" {
  description = "Warstwa wydajności Storage Account."
  type        = string
  default     = "Standard"
}

variable "account_replication_type" {
  description = "Typ replikacji Storage Account."
  type        = string
  default     = "LRS"
}

variable "private_endpoint_subnet_id" {
  description = "ID podsieci pod Private Endpointy — tu powstanie prywatny punkt dostępu do konta."
  type        = string
}
