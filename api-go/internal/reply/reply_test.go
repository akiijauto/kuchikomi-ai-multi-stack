package reply

import (
	"context"
	"strings"
	"testing"
)

func TestMockGenerate(t *testing.T) {
	p := Profile{StoreName: "テスト店", Industry: "飲食店", Tone: "polite", Signature: "店主 太郎"}

	t.Run("高評価は3案を返す", func(t *testing.T) {
		got, err := Mock{}.Generate(context.Background(), p, Review{Text: "美味しかったです", Rating: 5})
		if err != nil {
			t.Fatal(err)
		}
		if !got.Mock {
			t.Error("Mock が false になっている")
		}
		if len(got.Replies) != 3 {
			t.Fatalf("返信案が %d 件。期待は3件", len(got.Replies))
		}
		if !strings.Contains(got.Replies[1].Text, "テスト店") {
			t.Error("店名が本文に入っていない")
		}
	})

	t.Run("低評価は謝罪の文面になる", func(t *testing.T) {
		got, _ := Mock{}.Generate(context.Background(), p, Review{Text: "残念でした", Rating: 1})
		if !strings.Contains(got.Replies[0].Text, "申し訳") {
			t.Errorf("謝罪の文面ではない: %q", got.Replies[0].Text)
		}
	})

	t.Run("署名が無ければ何も足さない", func(t *testing.T) {
		noSig := p
		noSig.Signature = ""
		got, _ := Mock{}.Generate(context.Background(), noSig, Review{Text: "美味しかったです", Rating: 5})
		for _, r := range got.Replies {
			if strings.HasSuffix(r.Text, "\n") {
				t.Errorf("署名が無いのに改行が付いている: %q", r.Text)
			}
		}
	})
}

func TestWithSignature(t *testing.T) {
	in := []Reply{{Label: "標準", Text: "ありがとうございます"}}

	got := withSignature(in, "店主 太郎")
	if got[0].Text != "ありがとうございます\n\n店主 太郎" {
		t.Errorf("署名の付き方が違う: %q", got[0].Text)
	}
	// 元のスライスを書き換えていないこと(呼び出し側が使い回しても壊れない)
	if in[0].Text != "ありがとうございます" {
		t.Errorf("入力を書き換えている: %q", in[0].Text)
	}

	if withSignature(in, "")[0].Text != "ありがとうございます" {
		t.Error("署名が空なのに何か足している")
	}
}

func TestSystemPromptTone(t *testing.T) {
	// 未知の文体は polite にフォールバックする(TypeScript版・Ruby版と同じ)
	got := systemPrompt(Profile{StoreName: "店", Industry: "飲食店", Tone: "unknown-tone"})
	if !strings.Contains(got, toneInstructions["polite"]) {
		t.Error("未知の文体で polite に落ちていない")
	}
}

func TestTrimJSONFence(t *testing.T) {
	tests := map[string]string{
		`{"a":1}`:                 `{"a":1}`,
		"```json\n{\"a\":1}\n```": `{"a":1}`,
		"```\n{\"a\":1}\n```":     `{"a":1}`,
		"  \n {\"a\":1}   ":       `{"a":1}`,
	}
	for in, want := range tests {
		if got := trimJSONFence(in); got != want {
			t.Errorf("trimJSONFence(%q) = %q。期待は %q", in, got, want)
		}
	}
}
