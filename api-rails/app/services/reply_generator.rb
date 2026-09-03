require "anthropic"

# 口コミ返信文の生成。web/src/lib/generation/engine.ts の移植。
# APIキーが無いときはデモ返信を返すところまで同じにしてある
# （鍵が無い環境でも動作確認ができる。CIはこの経路を通る）。
class ReplyGenerator
  TONE_INSTRUCTIONS = {
    "polite" => "敬語を基本とした、誠実で落ち着いた文体。",
    "friendly" => "丁寧さを保ちつつ、親しみやすく温かい文体。絵文字は使わない。",
    "casual" => "常連客に話しかけるような砕けた文体。ただし礼儀は保つ。"
  }.freeze

  REPLY_SCHEMA = {
    type: "object",
    properties: {
      replies: {
        type: "array",
        items: {
          type: "object",
          properties: { label: { type: "string" }, text: { type: "string" } },
          required: %w[label text],
          additionalProperties: false
        }
      }
    },
    required: %w[replies],
    additionalProperties: false
  }.freeze

  Result = Struct.new(:replies, :mock, keyword_init: true)

  def initialize(profile:, review_text:, rating:)
    @profile = profile
    @review_text = review_text
    @rating = rating
  end

  def call
    return Result.new(replies: mock_replies, mock: true) if ENV["ANTHROPIC_API_KEY"].to_s.empty?

    message = client.messages.create(
      model: model_id,
      max_tokens: 2048,
      thinking: { type: "disabled" },
      output_config: {
        effort: "low",
        # format_ はRuby SDK側の属性名。送信時は format に変換される
        format_: { type: "json_schema", schema: REPLY_SCHEMA }
      },
      system_: system_prompt,
      messages: [ { role: "user", content: user_prompt } ]
    )

    text_block = message.content.find { |block| block.type == :text }
    raise "生成結果が空でした" if text_block.nil?

    replies = JSON.parse(text_block.text).fetch("replies")
    Result.new(replies: with_signature(replies), mock: false)
  end

  private

  attr_reader :profile, :review_text, :rating

  def client
    @client ||= Anthropic::Client.new
  end

  # TypeScript版と同じ既定値にしてある。切り替えは環境変数で行う
  def model_id
    ENV.fetch("GENERATION_MODEL", "claude-sonnet-4-6").to_sym
  end

  def with_signature(replies)
    return replies if profile.signature.to_s.empty?

    replies.map { |r| r.merge("text" => "#{r['text']}\n\n#{profile.signature}") }
  end

  def system_prompt
    <<~PROMPT
      あなたは「#{profile.store_name}」(業種: #{profile.industry})の店主として、Googleマップやホットペッパー等に投稿された口コミへの返信文を作成する専門家です。

      # 文体
      #{TONE_INSTRUCTIONS.fetch(profile.tone, TONE_INSTRUCTIONS['polite'])}
      署名や差出人名は書かない(本文のみを作成する。末尾に署名が別途自動で付与されるため)。

      # 返信作成のルール
      - 口コミ本文と同じ言語で返信文を作成する(英語の口コミには英語で、日本語の口コミには日本語で返信する)
      - まず来店と口コミ投稿への感謝を伝える
      - 口コミ本文の具体的な内容(メニュー名・スタッフ・体験など)に必ず触れ、定型文に見えない返信にする
      - 高評価(星4〜5): 喜びを伝え、さりげなく再来店を促す
      - 中評価(星3): 感謝+改善への姿勢を示す
      - 低評価(星1〜2): 言い訳をせず誠実に謝罪し、具体的な改善姿勢を示す。事実関係が不明な点は冷静に確認する姿勢を取る。感情的な反論は絶対にしない
      - 金銭的な補償や値引きの約束はしない
      - 投稿者の個人情報(来店日時の特定につながる情報など)には触れない
      - 各返信は100〜250文字程度

      # 出力
      アプローチの異なる返信文を必ず3案作成する(例: 標準的な返信 / より具体的に踏み込んだ返信 / 簡潔な返信)。
      各案には15文字以内の特徴ラベルを付ける。
    PROMPT
  end

  def user_prompt
    <<~PROMPT
      以下の口コミ(星#{rating}つ)への返信文を3案作成してください。

      <口コミ>
      #{review_text}
      </口コミ>
    PROMPT
  end

  def mock_replies
    sig = profile.signature.to_s.empty? ? "" : "\n#{profile.signature}"
    if rating <= 2
      [
        { "label" => "誠実な謝罪(デモ)", "text" => "この度はご不快な思いをさせてしまい、誠に申し訳ございませんでした。いただいたご指摘を真摯に受け止め、スタッフ一同サービスの改善に努めてまいります。#{sig}" },
        { "label" => "改善姿勢を強調(デモ)", "text" => "貴重なご意見をありがとうございます。ご指摘いただいた点について早急に見直しを行っております。もし機会をいただけましたら、改善した#{profile.store_name}をご体験いただけますと幸いです。#{sig}" },
        { "label" => "簡潔(デモ)", "text" => "この度は申し訳ございませんでした。いただいたお言葉を改善に活かしてまいります。#{sig}" }
      ]
    else
      [
        { "label" => "標準(デモ)", "text" => "この度はご来店と温かい口コミをありがとうございます。お楽しみいただけたようで、スタッフ一同大変嬉しく思います。またのご来店を心よりお待ちしております。#{sig}" },
        { "label" => "再来店を促す(デモ)", "text" => "嬉しい口コミをありがとうございます!#{profile.store_name}では季節ごとに新しいメニューもご用意しております。次回のご来店もぜひお楽しみにいらしてください。#{sig}" },
        { "label" => "簡潔(デモ)", "text" => "ご来店と口コミ投稿、ありがとうございます。またお会いできる日を楽しみにしております。#{sig}" }
      ]
    end
  end
end
