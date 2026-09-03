variable "region" {
  description = "デプロイ先リージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "name" {
  description = "リソース名の接頭辞"
  type        = string
  default     = "kuchikomi"
}

variable "allowed_cidr" {
  description = <<-EOT
    アプリ(:3000)へのアクセスを許す送信元。
    既定は全開放だが、動作確認だけなら自分のIPに絞ること（例: "203.0.113.4/32"）。
    ALBを置かない構成なので、この値がそのまま公開範囲になる。
  EOT
  type        = string
  default     = "0.0.0.0/0"
}

variable "image_tag" {
  description = "ECSに動かさせるECR上のイメージタグ"
  type        = string
  default     = "latest"
}

variable "desired_count" {
  description = "ECSタスク数。0にすると課金を止めつつ構成は残せる"
  type        = number
  default     = 1
}

# --- アプリの秘密値。terraform.tfvars（git追跡外）で渡す ---
variable "anthropic_api_key" {
  description = "Claude APIキー。空ならモックモードで動く"
  type        = string
  sensitive   = true
  default     = ""
}

variable "supabase_url" {
  description = "NEXT_PUBLIC_SUPABASE_URL（ビルド時に埋め込む公開値）"
  type        = string
  default     = ""
}

variable "supabase_anon_key" {
  description = "NEXT_PUBLIC_SUPABASE_ANON_KEY（公開値）"
  type        = string
  default     = ""
}

variable "supabase_service_role_key" {
  description = "SUPABASE_SERVICE_ROLE_KEY（秘匿）"
  type        = string
  sensitive   = true
  default     = ""
}

variable "rails_desired_count" {
  description = "Rails APIのタスク数。0にすると構成を残したまま課金を止められる"
  type        = number
  default     = 1
}

variable "rails_demo_mode" {
  description = <<-EOT
    デモ用トークン発行の口を開けるか。
    これは「誰でもログイン済みになれる入口」なので、
    公開範囲を自分のIPに絞っているときだけ true にする。
  EOT
  type        = bool
  default     = false
}

variable "go_desired_count" {
  description = "Go APIのタスク数。0にすると構成を残したまま課金を止められる"
  type        = number
  default     = 1
}

variable "go_demo_mode" {
  description = <<-EOT
    デモ用トークン発行の口を開けるか。
    これは「誰でもログイン済みになれる入口」なので、
    公開範囲を自分のIPに絞っているときだけ true にする。
  EOT
  type        = bool
  default     = false
}
