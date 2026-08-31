import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // コンテナ実行用。.next/standalone に「必要な node_modules だけ」を含む
  // 自己完結サーバー（server.js）を出力する。これがないと実行イメージに
  // node_modules を丸ごと入れる必要があり、イメージが数倍に膨らむ。
  output: "standalone",
};

export default nextConfig;
