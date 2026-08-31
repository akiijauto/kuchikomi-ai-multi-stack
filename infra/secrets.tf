# 秘密値は Secrets Manager ではなく SSM パラメータストア(Standard)に置く。
# Secrets Manager は1件$0.40/月かかるのに対し、SSM Standard は無料のため。
# ECSは secrets ブロックで、この ARN から実行時に値を読み込む
#   → タスク定義（コンソールで誰でも見られる）に平文が載らない。

locals {
  db_url = "postgresql://${aws_db_instance.main.username}:${urlencode(random_password.db.result)}@${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"

  # 未設定のものはパラメータを作らない。空文字を渡すとアプリ側が
  # 「未設定」ではなく「空」と受け取り、既定値へのフォールバックが効かなくなる
  # （本番リポジトリの振り返り「学び7」と同じ型の事故）。
  optional_secrets = {
    ANTHROPIC_API_KEY         = var.anthropic_api_key
    SUPABASE_SERVICE_ROLE_KEY = var.supabase_service_role_key
  }

  secret_values = merge(local.optional_secrets, { DATABASE_URL = local.db_url })

  # for_each には sensitive な値を渡せない（キー名としてstateに現れるため）。
  # ここで取り出しているのは「どの名前を作るか」だけで、値は含まない。
  # 明かしているのは "そのキーを設定したかどうか" のみ。
  enabled_secret_names = toset(concat(
    ["DATABASE_URL"], # DBのURLは常に作る
    nonsensitive([for k, v in local.optional_secrets : k if v != ""]),
  ))
}

resource "aws_ssm_parameter" "app" {
  for_each = local.enabled_secret_names

  name  = "/${var.name}/${each.value}"
  type  = "SecureString"
  value = local.secret_values[each.value]

  tags = { Name = "${var.name}-${lower(each.value)}" }
}
