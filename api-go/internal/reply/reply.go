// Package reply は口コミ返信文の生成を担う。
// web/src/lib/generation/engine.ts と api-rails の ReplyGenerator の移植で、
// APIキーが無いときはデモ返信を返すところまで同じにしてある
// (鍵が無い環境でも経路の確認ができる。CIはこの経路を通る)。
package reply

import (
	"context"
	"fmt"
	"strings"
)

// Profile は生成に必要なぶんだけの店舗情報。
type Profile struct {
	StoreName string
	Industry  string
	Tone      string
	Signature string
}

// Review は入力された口コミ。
type Review struct {
	Text   string
	Rating int
}

// Reply は返信案1つ。JSONのキー名はNext.js版・Rails版に合わせる
// (同じ画面から差し替えて呼べるようにするため)。
type Reply struct {
	Label string `json:"label"`
	Text  string `json:"text"`
}

// Result は生成結果。Mock は「APIキーが無いのでデモ返信を返した」ことを示す。
type Result struct {
	Replies []Reply `json:"replies"`
	Mock    bool    `json:"mock"`
}

// toneInstructions は文体の指示。TypeScript版・Ruby版と同じ文言。
var toneInstructions = map[string]string{
	"polite":   "敬語を基本とした、誠実で落ち着いた文体。",
	"friendly": "丁寧さを保ちつつ、親しみやすく温かい文体。絵文字は使わない。",
	"casual":   "常連客に話しかけるような砕けた文体。ただし礼儀は保つ。",
}

// Generator は返信文を作る。
type Generator interface {
	Generate(ctx context.Context, p Profile, r Review) (Result, error)
}

// systemPrompt / userPrompt は3実装で同じ文面にしてある。
// 文面が同じなら、実装言語を替えても出力の傾向が変わらないことを確かめられる。
func systemPrompt(p Profile) string {
	tone, ok := toneInstructions[p.Tone]
	if !ok {
		tone = toneInstructions["polite"]
	}
	return fmt.Sprintf(`あなたは「%s」(業種: %s)の店主として、Googleマップやホットペッパー等に投稿された口コミへの返信文を作成する専門家です。

# 文体
%s
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
`, p.StoreName, p.Industry, tone)
}

func userPrompt(r Review) string {
	return fmt.Sprintf(`以下の口コミ(星%dつ)への返信文を3案作成してください。

<口コミ>
%s
</口コミ>
`, r.Rating, r.Text)
}

// withSignature は各案の末尾へ署名を付ける。署名が空なら何もしない。
func withSignature(replies []Reply, signature string) []Reply {
	if signature == "" {
		return replies
	}
	out := make([]Reply, len(replies))
	for i, r := range replies {
		out[i] = Reply{Label: r.Label, Text: r.Text + "\n\n" + signature}
	}
	return out
}

// Mock は APIキーが無いときに使う定型返信。
// 「動かないから止まる」のではなく「経路は通るが中身はデモ」にしておくと、
// 鍵の無いCIでも認証・上限・レスポンス形式まで通して確かめられる。
type Mock struct{}

// Generate はデモ返信を3案返す。
func (Mock) Generate(_ context.Context, p Profile, r Review) (Result, error) {
	sig := ""
	if p.Signature != "" {
		sig = "\n" + p.Signature
	}
	var replies []Reply
	if r.Rating <= 2 {
		replies = []Reply{
			{Label: "誠実な謝罪(デモ)", Text: "この度はご不快な思いをさせてしまい、誠に申し訳ございませんでした。いただいたご指摘を真摯に受け止め、スタッフ一同サービスの改善に努めてまいります。" + sig},
			{Label: "改善姿勢を強調(デモ)", Text: "貴重なご意見をありがとうございます。ご指摘いただいた点について早急に見直しを行っております。もし機会をいただけましたら、改善した" + p.StoreName + "をご体験いただけますと幸いです。" + sig},
			{Label: "簡潔(デモ)", Text: "この度は申し訳ございませんでした。いただいたお言葉を改善に活かしてまいります。" + sig},
		}
	} else {
		replies = []Reply{
			{Label: "標準(デモ)", Text: "この度はご来店と温かい口コミをありがとうございます。お楽しみいただけたようで、スタッフ一同大変嬉しく思います。またのご来店を心よりお待ちしております。" + sig},
			{Label: "再来店を促す(デモ)", Text: "嬉しい口コミをありがとうございます!" + p.StoreName + "では季節ごとに新しいメニューもご用意しております。次回のご来店もぜひお楽しみにいらしてください。" + sig},
			{Label: "簡潔(デモ)", Text: "ご来店と口コミ投稿、ありがとうございます。またお会いできる日を楽しみにしております。" + sig},
		}
	}
	return Result{Replies: replies, Mock: true}, nil
}

// trimJSONFence は、稀に ```json … ``` で囲まれて返るときのための保険。
func trimJSONFence(s string) string {
	s = strings.TrimSpace(s)
	if !strings.HasPrefix(s, "```") {
		return s
	}
	s = strings.TrimPrefix(s, "```json")
	s = strings.TrimPrefix(s, "```")
	return strings.TrimSpace(strings.TrimSuffix(strings.TrimSpace(s), "```"))
}
