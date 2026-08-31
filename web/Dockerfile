# syntax=docker/dockerfile:1
#
# クチコミ返信AI (Next.js 16 / App Router) のコンテナイメージ。
# マルチステージ構成にして、実行イメージに開発依存とソースを残さない。
#   deps    : 依存インストールだけを行う層（package*.json が変わらない限りキャッシュが効く）
#   builder : 本番ビルド（standalone 出力）
#   runner  : 実行専用。node_modules 全体ではなく standalone の最小依存だけを持つ
#   dev     : docker compose でのローカル開発用（ホットリロード）

# ---- 1. 依存インストール ----
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

# ---- 2. ビルド ----
FROM node:22-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# NEXT_PUBLIC_* はビルド時にクライアントJSへ埋め込まれるため、実行時のenvでは差し替わらない。
# 秘密鍵ではない公開値だけをビルド引数で受け取り、未指定でもイメージが作れるようダミーを既定にする。
ARG NEXT_PUBLIC_SUPABASE_URL=http://localhost:54321
ARG NEXT_PUBLIC_SUPABASE_ANON_KEY=dummy-anon-key-for-build
ARG NEXT_PUBLIC_OPERATOR_NAME=
ARG NEXT_PUBLIC_OPERATOR_EMAIL=
ARG NEXT_PUBLIC_GA_MEASUREMENT_ID=
ARG NEXT_PUBLIC_META_PIXEL_ID=
ENV NEXT_PUBLIC_SUPABASE_URL=$NEXT_PUBLIC_SUPABASE_URL \
    NEXT_PUBLIC_SUPABASE_ANON_KEY=$NEXT_PUBLIC_SUPABASE_ANON_KEY \
    NEXT_PUBLIC_OPERATOR_NAME=$NEXT_PUBLIC_OPERATOR_NAME \
    NEXT_PUBLIC_OPERATOR_EMAIL=$NEXT_PUBLIC_OPERATOR_EMAIL \
    NEXT_PUBLIC_GA_MEASUREMENT_ID=$NEXT_PUBLIC_GA_MEASUREMENT_ID \
    NEXT_PUBLIC_META_PIXEL_ID=$NEXT_PUBLIC_META_PIXEL_ID \
    NEXT_TELEMETRY_DISABLED=1
RUN npm run build

# ---- 3. 実行 ----
FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000 \
    HOSTNAME=0.0.0.0

# root で動かさない（コンテナが乗っ取られたときの被害を抑える基本対策）
RUN addgroup -g 1001 -S nodejs && adduser -S -u 1001 -G nodejs nextjs

COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3000

# /api/health は proxy.ts の matcher から除外してあるため、認証基盤に依存せず応答する
HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:3000/api/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "server.js"]

# ---- 4. 開発用（compose の web サービスから target: dev で使う）----
FROM node:22-alpine AS dev
WORKDIR /app
ENV NODE_ENV=development \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000 \
    HOSTNAME=0.0.0.0
COPY --from=deps /app/node_modules ./node_modules
COPY . .
EXPOSE 3000
CMD ["npm", "run", "dev"]
