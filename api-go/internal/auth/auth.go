// Package auth は Supabase が発行した JWT の検証を行う。
//
// Next.js版は supabase-js の auth.getUser() が裏でこれをやっている。
// Rails版は jwt gem で同じことを自前でやった。Go版も依存は変わるが中身は同じで、
// 「署名が正しいか」と「誰なのか(sub)」を取り出すだけ。
package auth

import (
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// ErrUnauthorized は「トークンが無い・壊れている・期限切れ・別の鍵で署名」の総称。
// どれであったかは呼び出し側にも利用者にも返さない(攻撃者への情報提供になる)。
var ErrUnauthorized = errors.New("unauthorized")

// Verify はトークンを検証し、利用者ID(sub)を返す。
func Verify(token, secret string) (string, error) {
	var claims jwt.RegisteredClaims

	// WithValidMethods は飾りではない。これが無いと、トークンのヘッダに書かれた
	// alg をライブラリが信じてしまう経路が生まれる(alg混同攻撃)。
	// 受け入れる署名方式はこちらが決める、という形にしておく。
	_, err := jwt.ParseWithClaims(token, &claims, func(*jwt.Token) (any, error) {
		return []byte(secret), nil
	}, jwt.WithValidMethods([]string{"HS256"}))
	if err != nil {
		return "", ErrUnauthorized
	}
	if claims.Subject == "" {
		return "", ErrUnauthorized
	}
	return claims.Subject, nil
}

// Issue はデモ画面用に、Supabaseが出すものと同じ形のトークンを作る。
// 本番でこれを使うことはない(呼び出し口は DEMO_MODE のときだけ生える)。
func Issue(userID, secret string, ttl time.Duration) (string, error) {
	now := time.Now()
	return jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.RegisteredClaims{
		Subject:   userID,
		Audience:  jwt.ClaimStrings{"authenticated"},
		IssuedAt:  jwt.NewNumericDate(now),
		ExpiresAt: jwt.NewNumericDate(now.Add(ttl)),
	}).SignedString([]byte(secret))
}

// BearerToken は Authorization ヘッダからトークン部分を取り出す。
// 形式が違えば空文字を返す(errorにしないのは、呼び出し側の扱いが同じため)。
func BearerToken(r *http.Request) string {
	const prefix = "Bearer "
	h := r.Header.Get("Authorization")
	if !strings.HasPrefix(h, prefix) {
		return ""
	}
	return strings.TrimSpace(strings.TrimPrefix(h, prefix))
}
