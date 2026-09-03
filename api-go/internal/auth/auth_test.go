package auth

import (
	"net/http/httptest"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const secret = "test-secret-for-go-tests-only-not-a-real-key"

func TestVerify(t *testing.T) {
	valid, err := Issue("user-1", secret, time.Hour)
	if err != nil {
		t.Fatalf("トークンを作れなかった: %v", err)
	}
	expired, err := Issue("user-1", secret, -time.Minute)
	if err != nil {
		t.Fatalf("期限切れトークンを作れなかった: %v", err)
	}
	otherKey, err := Issue("user-1", "another-secret", time.Hour)
	if err != nil {
		t.Fatalf("別鍵トークンを作れなかった: %v", err)
	}

	// 署名なし(alg=none)のトークン。WithValidMethods が効いていなければ通ってしまう。
	unsigned, err := jwt.NewWithClaims(jwt.SigningMethodNone,
		jwt.RegisteredClaims{Subject: "user-1"}).SignedString(jwt.UnsafeAllowNoneSignatureType)
	if err != nil {
		t.Fatalf("無署名トークンを作れなかった: %v", err)
	}

	noSubject, err := jwt.NewWithClaims(jwt.SigningMethodHS256,
		jwt.RegisteredClaims{ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Hour))}).
		SignedString([]byte(secret))
	if err != nil {
		t.Fatalf("sub無しトークンを作れなかった: %v", err)
	}

	tests := []struct {
		name    string
		token   string
		wantSub string
		wantErr bool
	}{
		{name: "正しいトークンはsubを返す", token: valid, wantSub: "user-1"},
		{name: "期限切れは拒否", token: expired, wantErr: true},
		{name: "別の鍵で署名されたものは拒否", token: otherKey, wantErr: true},
		{name: "alg=none は拒否", token: unsigned, wantErr: true},
		{name: "subが無ければ拒否", token: noSubject, wantErr: true},
		{name: "空文字は拒否", token: "", wantErr: true},
		{name: "壊れた文字列は拒否", token: "not.a.token", wantErr: true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			sub, err := Verify(tt.token, secret)
			if tt.wantErr {
				if err == nil {
					t.Fatalf("拒否されるはずが通った (sub=%q)", sub)
				}
				return
			}
			if err != nil {
				t.Fatalf("通るはずが拒否された: %v", err)
			}
			if sub != tt.wantSub {
				t.Fatalf("sub が %q。期待は %q", sub, tt.wantSub)
			}
		})
	}
}

func TestBearerToken(t *testing.T) {
	tests := []struct {
		header string
		want   string
	}{
		{"Bearer abc", "abc"},
		{"Bearer  abc  ", "abc"},
		{"bearer abc", ""}, // 大文字小文字は区別する(Rails版と同じ)
		{"Basic abc", ""},
		{"abc", ""},
		{"", ""},
	}
	for _, tt := range tests {
		r := httptest.NewRequest("POST", "/api/generate", nil)
		if tt.header != "" {
			r.Header.Set("Authorization", tt.header)
		}
		if got := BearerToken(r); got != tt.want {
			t.Errorf("Authorization=%q → %q。期待は %q", tt.header, got, tt.want)
		}
	}
}
