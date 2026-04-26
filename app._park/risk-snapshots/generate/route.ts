// app/api/risk-snapshots/generate/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { requireDbOrganization } from "@/lib/org-db";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

/* -------------------------------------------------------------------------- */
/* Utils                                                                      */
/* -------------------------------------------------------------------------- */

function safeStr(v: unknown) {
  return typeof v === "string" ? v.trim() : "";
}

function num(v: unknown): number | null {
  const n = Number(String(v ?? "").trim());
  return Number.isFinite(n) && n > 0 ? n : null;
}

function json(payload: any, status = 200) {
  return NextResponse.json(payload, { status });
}

async function readBodyAny(req: Request): Promise<{ ok: true; body: any } | { ok: false; error: string }> {
  try {
    const body = await req.json();
    return { ok: true as const, body };
  } catch {
    return { ok: false as const, error: "invalid_json" };
  }
}

function riskLabel(score?: number | null) {
  if (typeof score !== "number" || !Number.isFinite(score)) return "—";
  if (score >= 80) return "High";
  if (score >= 50) return "Medium";
  return "Low";
}

/* -------------------------------------------------------------------------- */
/* Route                                                                      */
/* -------------------------------------------------------------------------- */

export async function POST(req: Request) {
  const routeSig = "risk-snapshots/generate";

  const org = await requireDbOrganization().catch(() => null);
  const orgId = Number((org as any)?.id);
  if (!Number.isFinite(orgId) || orgId <= 0) {
    return json({ ok: false, routeSig, error: "unauthorized" }, 401);
  }

  const bodyRes = await readBodyAny(req);
  if (!bodyRes.ok) {
    // ✅ FIX: do NOT spread bodyRes because it already contains ok:false
    return json({ ok: false, routeSig, error: bodyRes.error }, 400);
  }

  const url = new URL(req.url);
  const qVendorId = url.searchParams.get("vendorId");
  const vendorId = num(bodyRes.body?.vendorId) ?? num(qVendorId);

  if (!vendorId) {
    return json({ ok: false, routeSig, error: "missing_vendorId" }, 400);
  }

  // Verify vendor in org
  const vendor = await prisma.vendor.findFirst({
    where: { id: vendorId, organizationId: orgId },
    select: { id: true, name: true, riskScore: true },
  });

  if (!vendor) {
    return json({ ok: false, routeSig, error: "vendor_not_found" }, 404);
  }

  // Generate a snapshot row using current vendor riskScore (schema-safe)
  const score = typeof vendor.riskScore === "number" ? vendor.riskScore : null;

  const snap = await prisma.vendorRiskSnapshot.create({
    data: {
      organizationId: orgId,
      vendorId: vendor.id,
      score: score ?? undefined,
      label: score === null ? "—" : riskLabel(score),
      summary: `Generated snapshot for ${vendor.name}${score === null ? "" : ` (score ${score})`}`,
    },
    select: { id: true, vendorId: true, score: true, label: true, createdAt: true },
  });

  return json({
    ok: true,
    routeSig,
    vendor: { id: vendor.id, name: vendor.name },
    snapshot: snap,
  });
}
