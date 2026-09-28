output "greeting_path" {
  description = "Ścieżka do wygenerowanego pliku powitania."
  value       = local_file.greeting.filename
}
