variable "name" {
  description = "Imię/inicjały uczestnika, użyte w treści powitania."
  type        = string
  default     = "Uczestniku"
}

variable "subscription_id" {
  description = "ID subskrypcji Azure."
  type        = string
}

variable "resource_group_name" {
  description = "Nazwa istniejącej grupy zasobów przygotowanej na warsztat."
  type        = string
}

variable "project" {
  description = "Krótki identyfikator projektu, używany w nazwach zasobów."
  type        = string
  default     = "tftrain"

  validation {
    condition     = can(regex("^[a-z0-9-]{2,8}$", var.project))
    error_message = "project: tylko małe litery, cyfry i myślniki, 2-8 znaków."
  }
}

variable "owner" {
  description = "Twoje inicjały — wchodzą w nazwę każdego zasobu, żeby uniknąć kolizji (w tym globalnych, np. Storage Account)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{2,6}$", var.owner))
    error_message = "owner: tylko małe litery i cyfry, 2-6 znaków."
  }
}
