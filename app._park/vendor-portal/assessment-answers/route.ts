// app/api/vendor-portal/assessment-answers/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { auth } from "@clerk/nextjs/server";
import { requireDbOrganization } from "@/lib/org-db";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

async function resolveVendorIdForUser(userId: string): Promise<number | null> {
  const anyPrisma: any = prisma;

  if (typeof anyPrisma.vendorUser?.findFirst === "function") {
    const vu = await anyPrisma.vendorUser
      .findFirst({
        where: { userId },
        select: { vendorId: true },
      })
      .catch(() => null);
    if (vu?.vendorId) return Number(vu.vendorId);
  }

  const candidates = ["portalUserId", "userId", "clerkUserId"];
  for (const field of candidates) {
    try {
      const v = await prisma.vendor.findFirst({
        where: { [field]: userId } as any,
        select: { id: true },
      });
      if (v?.id) return Number(v.id);
    } catch {
      // ignore
    }
  }

  return null;
}

function valueToString(v: any): string {
  if (v === null || v === undefined) return "";
  if (typeof v === "string") return v;
  if (typeof v === "number" || typeof v === "boolean") return String(v);
  try {
    return JSON.stringify(v);
  } catch {
    return String(v);
  }
}

async function runBelongsToOrgOrVendor(args: {
  assessmentId: number;
  vendorId: number;
  userId: string;
}): Promise<{ ok: true; mode: "vendor" | "org" } | { ok: false; status: number; error: string }> {
  const { assessmentId, vendorId, userId } = args;

  // Resolve "run" model: some envs use assessmentRun, others use assessment
  const RunModel: any = (prisma as any).assessmentRun ?? (prisma as any).assessment;

  if (!RunModel?.findUnique) {
    return { ok: false, status: 400, error: "Assessments not available" };
  }

  // Fetch run + vendor + org ownership
  const run = await RunModel.findUnique({
    where: { id: assessmentId },
    select: {
      id: true,
      vendorId: true,
      vendor: { select: { id: true, organizationId: true } },
    },
  }).catch(() => null);

  const runVendorId = Number(run?.vendorId);
  const runOrgId = Number(run?.vendor?.organizationId);

  if (!run || !Number.isFinite(runVendorId)) {
    return { ok: false, status: 404, error: "Run not found" };
  }

  // If payload vendorId doesn't match the run, reject
  if (runVendorId !== vendorId) {
    return { ok: false, status: 403, error: "Forbidden" };
  }

  // 1) Vendor-portal auth path (must be vendor user)
  const resolvedVendorId = await resolveVendorIdForUser(userId);
  if (resolvedVendorId && resolvedVendorId === vendorId) {
    return { ok: true, mode: "vendor" };
  }

  // 2) Internal org member path (allow signed-in org members)
  // If requireDbOrganization throws (not signed in / no org), we treat as not authorized.
  try {
    const org = await requireDbOrganization();
    if (Number.isFinite(runOrgId) && runOrgId === Number(org.id)) {
      return { ok: true, mode: "org" };
    }
  } catch {
    // ignore -> fallthrough forbidden
  }

  return { ok: false, status: 403, error: "Forbidden" };
}

export async function POST(req: Request) {
  try {
    const { userId } = await auth();
    if (!userId) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const body = await req.json().catch(() => null);
    const assessmentId = Number(body?.assessmentId);
    const vendorId = Number(body?.vendorId);
    const questionId = Number(body?.questionId);
    const rawValue = body?.value;

    if (
      !Number.isFinite(assessmentId) ||
      !Number.isFinite(questionId) ||
      !Number.isFinite(vendorId)
    ) {
      return NextResponse.json({ error: "Invalid payload" }, { status: 400 });
    }

    const authz = await runBelongsToOrgOrVendor({
      assessmentId,
      vendorId,
      userId,
    });

    if (!authz.ok) {
      return NextResponse.json({ error: authz.error }, { status: authz.status });
    }

    // Upsert answer: (assessmentId, questionId) unique-ish, but schemas vary.
    // Use findFirst + update/create to stay schema-safe.
    const anyPrisma: any = prisma;
    if (typeof anyPrisma.assessmentAnswer?.findFirst !== "function") {
      return NextResponse.json(
        { error: "Assessment answers not available" },
        { status: 400 }
      );
    }

    const now = new Date();
    const valueStr = valueToString(rawValue);

    const existing = await anyPrisma.assessmentAnswer
      .findFirst({
        where: { assessmentId, questionId },
        select: { id: true },
      })
      .catch(() => null);

    let saved: any = null;

    if (existing?.id && typeof anyPrisma.assessmentAnswer.update === "function") {
      saved = await anyPrisma.assessmentAnswer.update({
        where: { id: existing.id },
        data: {
          value: valueStr,
          valueJson: rawValue ?? null,
          updatedAt: now,
        },
        select: {
          id: true,
          assessmentId: true,
          questionId: true,
          value: true,
          valueJson: true,
          updatedAt: true,
        },
      });
    } else if (typeof anyPrisma.assessmentAnswer.create === "function") {
      saved = await anyPrisma.assessmentAnswer.create({
        data: {
          assessmentId,
          questionId,
          value: valueStr,
          valueJson: rawValue ?? null,
          updatedAt: now,
        },
        select: {
          id: true,
          assessmentId: true,
          questionId: true,
          value: true,
          valueJson: true,
          updatedAt: true,
        },
      });
    }

    // Keep assessment updatedAt fresh (helps lists)
    const RunModel: any = (prisma as any).assessmentRun ?? (prisma as any).assessment;
    if (RunModel?.update) {
      await RunModel.update({
        where: { id: assessmentId },
        data: { updatedAt: now } as any,
      }).catch(() => null);
    }

    return NextResponse.json({ ok: true, mode: authz.mode, answer: saved });
  } catch (e: any) {
    return NextResponse.json(
      { error: e?.message || "Server error" },
      { status: 500 }
    );
  }
}

