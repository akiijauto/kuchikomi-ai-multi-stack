package reply

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/anthropics/anthropic-sdk-go"
)

// defaultModel は TypeScript版・Ruby版と同じ既定値。
// 3実装で同じモデル・同じプロンプトにしておかないと、
// 出力の違いが「言語の違い」なのか「設定の違い」なのか分からなくなる。
// 切り替えは GENERATION_MODEL 環境変数で行う。
const defaultModel = "claude-sonnet-4-6"

// replySchema は返信案の形。構造化出力で形を保証させ、
// 「JSONのつもりが散文だった」を実行時に持ち込まないようにする。
var replySchema = map[string]any{
	"type": "object",
	"properties": map[string]any{
		"replies": map[string]any{
			"type": "array",
			"items": map[string]any{
				"type": "object",
				"properties": map[string]any{
					"label": map[string]any{"type": "string"},
					"text":  map[string]any{"type": "string"},
				},
				"required":             []string{"label", "text"},
				"additionalProperties": false,
			},
		},
	},
	"required":             []string{"replies"},
	"additionalProperties": false,
}

// Claude は Anthropic API を呼ぶ生成器。
type Claude struct {
	client anthropic.Client
	model  anthropic.Model
}

// NewClaude は生成器を作る。model が空なら既定値を使う。
// APIキーは SDK が ANTHROPIC_API_KEY から読む。
func NewClaude(model string) *Claude {
	if model == "" {
		model = defaultModel
	}
	return &Claude{client: anthropic.NewClient(), model: anthropic.Model(model)}
}

// Generate は返信案を3つ作る。
func (c *Claude) Generate(ctx context.Context, p Profile, r Review) (Result, error) {
	msg, err := c.client.Messages.New(ctx, anthropic.MessageNewParams{
		Model:     c.model,
		MaxTokens: 2048,
		// 返信文の作成に長い推論は要らない。既定のまま投げると
		// 待ち時間とトークンを無駄に使う(Ruby版と同じ設定に揃えてある)。
		Thinking: anthropic.ThinkingConfigParamUnion{
			OfDisabled: &anthropic.ThinkingConfigDisabledParam{},
		},
		OutputConfig: anthropic.OutputConfigParam{
			Effort: anthropic.OutputConfigEffortLow,
			Format: anthropic.JSONOutputFormatParam{Schema: replySchema},
		},
		System: []anthropic.TextBlockParam{{Text: systemPrompt(p)}},
		Messages: []anthropic.MessageParam{
			anthropic.NewUserMessage(anthropic.NewTextBlock(userPrompt(r))),
		},
	})
	if err != nil {
		return Result{}, fmt.Errorf("生成の呼び出しに失敗しました: %w", err)
	}

	text := ""
	for _, block := range msg.Content {
		if b, ok := block.AsAny().(anthropic.TextBlock); ok {
			text = b.Text
			break
		}
	}
	if text == "" {
		return Result{}, errors.New("生成結果が空でした")
	}

	var parsed struct {
		Replies []Reply `json:"replies"`
	}
	if err := json.Unmarshal([]byte(trimJSONFence(text)), &parsed); err != nil {
		return Result{}, fmt.Errorf("生成結果を読み取れませんでした: %w", err)
	}
	if len(parsed.Replies) == 0 {
		return Result{}, errors.New("返信案が1件も返りませんでした")
	}

	return Result{Replies: withSignature(parsed.Replies, p.Signature), Mock: false}, nil
}
