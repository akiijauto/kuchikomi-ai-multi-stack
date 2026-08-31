import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import { Footer } from "./footer";
import { Analytics } from "@vercel/analytics/next";
import { AnalyticsScripts } from "./analytics-scripts";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "クチコミ返信AI | 口コミ返信文を10秒で作成",
  description:
    "美容室・サロン・飲食店向け。Googleマップやホットペッパーの口コミへの返信文をAIが自動作成。貼り付けるだけで、お店らしい返信が3案できあがります。",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="ja"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col">
        {children}
        <Footer />
        <Analytics />
        <AnalyticsScripts />
      </body>
    </html>
  );
}
