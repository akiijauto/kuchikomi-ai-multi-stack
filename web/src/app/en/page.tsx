import type { Metadata } from "next";
import Link from "next/link";
import { PLAN_LIMITS, PLAN_PRICES } from "@/lib/plans";
import { LinkPending } from "../link-pending";

const PLAN_LABELS_EN = { free: "Free Plan", pro: "Pro Plan" } as const;

export const metadata: Metadata = {
  title: "Review Reply AI | Draft review replies in 10 seconds",
};

export default function EnglishLandingPage() {
  return (
    <main className="mx-auto w-full max-w-xl px-4 py-12">
      <section className="text-center">
        <h1 className="text-3xl font-bold">Review Reply AI</h1>
        <p className="mt-4 text-base text-gray-600">
          AI drafts the reply, you just pick one. No more staring at a blank
          box trying to word a review response.
        </p>
        <p className="mt-2 text-sm text-gray-500">
          Built for salon, spa, and restaurant owners. Set up your store
          profile once, then paste in any customer review &mdash; in English
          or Japanese &mdash; and get 3 reply drafts that sound like you.
        </p>
        <div className="mt-8 flex flex-col gap-3 sm:flex-row sm:justify-center">
          <Link
            href="/login"
            className="rounded-xl bg-blue-600 px-6 py-3 font-semibold text-white"
          >
            Start for free
            <LinkPending />
          </Link>
          <Link
            href="/login"
            className="rounded-xl border border-gray-300 px-6 py-3 font-semibold text-gray-700"
          >
            Log in
            <LinkPending />
          </Link>
        </div>
        <p className="mt-3 text-xs text-gray-400">
          No credit card required &mdash; just an email address. Free plan
          includes up to {PLAN_LIMITS.free} replies per month.
        </p>
      </section>

      <section className="mt-16 grid gap-6">
        <div className="rounded-xl border border-gray-200 p-5">
          <h2 className="font-semibold">Just paste the review</h2>
          <p className="mt-1 text-sm text-gray-500">
            Drop in the customer&apos;s review text and star rating, and AI
            instantly drafts reply candidates &mdash; matching the review&apos;s
            language.
          </p>
        </div>
        <div className="rounded-xl border border-gray-200 p-5">
          <h2 className="font-semibold">3 drafts in your store&apos;s voice</h2>
          <p className="mt-1 text-sm text-gray-500">
            Set your industry and tone (polite, friendly, etc.) once, and
            every reply matches your store&apos;s personality.
          </p>
        </div>
        <div className="rounded-xl border border-gray-200 p-5">
          <h2 className="font-semibold">Copy and paste, done</h2>
          <p className="mt-1 text-sm text-gray-500">
            Tap to copy your favorite draft and paste it straight into Google
            Maps, Yelp, or any review platform&apos;s reply box.
          </p>
        </div>
      </section>

      <section className="mt-16">
        <h2 className="text-center text-xl font-bold">Pricing</h2>
        <div className="mt-6 grid gap-4 sm:grid-cols-2">
          <div className="rounded-xl border border-gray-200 p-5 text-center">
            <h3 className="font-semibold">{PLAN_LABELS_EN.free}</h3>
            <p className="mt-2 text-2xl font-bold">Free</p>
            <p className="mt-2 text-sm text-gray-500">
              Up to {PLAN_LIMITS.free} replies per month
            </p>
          </div>
          <div className="rounded-xl border-2 border-blue-600 p-5 text-center">
            <h3 className="font-semibold">{PLAN_LABELS_EN.pro}</h3>
            <p className="mt-2 text-2xl font-bold">
              &yen;{PLAN_PRICES.pro}
              <span className="text-sm font-normal">/month</span>
            </p>
            <p className="mt-2 text-sm text-gray-500">
              Up to {PLAN_LIMITS.pro} replies per month &mdash; more than
              enough for most small shops.
            </p>
          </div>
        </div>
        <p className="mt-4 text-center">
          <Link href="/login" className="text-sm text-blue-600">
            Try the free plan now &rarr;
            <LinkPending />
          </Link>
        </p>
      </section>

      <footer className="mt-12 text-center text-xs text-gray-400">
        Review Reply AI (beta)
      </footer>
    </main>
  );
}
