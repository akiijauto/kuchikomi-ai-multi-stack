# syntax=docker/dockerfile:1

# Go実装の実行イメージ。
# Next.js版(202MB) / Rails版と並べて、同じ機能が実行時に何を必要とするかを比べられるようにしてある。

FROM golang:1.27-alpine AS build
WORKDIR /src

# 依存の取得だけ先に済ませる。go.mod / go.sum が変わらない限りこの層は再利用される。
COPY go.mod go.sum ./
RUN go mod download

COPY . .

# CGO_ENABLED=0 で完全に静的なバイナリにする。libc に依存しなくなるので、
# 実行イメージに OS のユーザーランドを一切置かなくて済む。
# -trimpath はビルドしたマシンの絶対パスをバイナリに残さないため。
# -ldflags="-s -w" はデバッグ情報を落としてサイズを減らすため。
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/api ./cmd/api

# distroless/static: CA証明書・タイムゾーン・nonroot ユーザーだけが入った土台。
# シェルもパッケージマネージャも入っていないので、侵入されても手足が無い。
# scratch にしなかったのは、Anthropic API を HTTPS で呼ぶのに CA 証明書が要るため。
FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /app

COPY --from=build /out/api /app/api
COPY public /app/public

ENV PUBLIC_DIR=/app/public \
    PORT=8080

USER nonroot:nonroot
EXPOSE 8080

# シェルが無いので `CMD curl ...` は書けない。バイナリ自身に自分を叩かせる
# (-healthcheck フラグ)。exec 形式なのでシェルを介さず起動できる。
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD ["/app/api", "-healthcheck"]

ENTRYPOINT ["/app/api"]
