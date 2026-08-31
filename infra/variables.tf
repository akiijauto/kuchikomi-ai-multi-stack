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
