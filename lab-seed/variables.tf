variable "subscription_id" {
  description = "ID subskrypcji Azure, w której powstaną grupy zasobów uczestników."
  type        = string
}

variable "tenant_domain" {
  description = "Domena Entra ID (np. \"wgAADtest01.onmicrosoft.com\"), używana do budowy UPN uczestników."
  type        = string
}

variable "location" {
  description = "Region Azure dla grup zasobów uczestników."
  type        = string
  default     = "westeurope"
}

variable "group_name" {
  description = "Nazwa grupy Entra ID, do której trafią wszyscy utworzeni uczestnicy. Grupa dostaje rolę Reader na każdej grupie zasobów uczestników — dzięki temu widzą nawzajem swoje RG, ale nic poza nimi w subskrypcji."
  type        = string
}

variable "trainee_count" {
  description = "Liczba kont uczestników do utworzenia. Loginy generują się same jako user<4 losowe znaki>-<licznik>."
  type        = number

  validation {
    condition     = var.trainee_count > 0 && var.trainee_count <= 100
    error_message = "trainee_count musi być liczbą od 1 do 100."
  }
}
