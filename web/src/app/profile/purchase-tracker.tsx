"use client";

import { useEffect } from "react";
import { trackFirstPurchase } from "@/lib/analytics";
import { PLAN_PRICES } from "@/lib/plans";

// Stripe の success_url(/profile?checkout=success&session_id=...) 着地時に
// first_purchase を1回だけ撃つ。URLは window から読むので Suspense 境界は不要。
export function PurchaseTracker() {
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    if (params.get("checkout") !== "success") return;
    const sessionId = params.get("session_id");
    if (sessionId) trackFirstPurchase(sessionId, PLAN_PRICES.pro);
  }, []);
  return null;
}
