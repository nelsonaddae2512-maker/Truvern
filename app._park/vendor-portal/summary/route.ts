// app/api/vendor-portal/summary/route.ts
import { NextResponse } from "next/server";
import { auth, currentUser } from "@clerk/nextjs/server";
import prisma from "@/lib/prisma";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function json(data: any, status = 200) {
  return NextResponse.json(data, { status });
}

function pickEmail(u: any): string | null {
  const primary = u?.primaryEmailAddress?.emailAddress;
  if (primary) return String(primary).trim().toLowerCase();
  const first = u?.emailAddresses?.[0]?.emailAddress;
  if (first) return String(first).trim().toLowerCase();
  return null;
}

function isDevBypass(req: Request) {
  return req.headers.get("x-dev-bypass") === "1";
}

async function getLinkedVendorIdForDev(req: Request) {
  const email = (req.headers.get("x-dev-email") || "").trim().toLowerCase() || null;

  const link = await prisma.vendorPortalUser.findFirst({
    where: email ? { email } : {},
    orderBy: { id: "asc" },
    select: { vendorId: true, email: true },
  });

  return {
    vendorId: link?.vendorId ?? null,
    email: link?.email ?? email,
    mode: "dev-bypass",
  };
}

async function buildSummaryForVendor(vendorId: number) {
  const vendor = await prisma.vendor.findUnique({
    where: { id: vendorId },
    select: {
      id: true,
      name: true,
      summary: true,
      category: true,
      tier: true,
      criticality: true,
      status: true,
      updatedAt: true,
    },
  });

  if (!vendor) {
    return {
      linked: true,
      vendor: null,
      stats: {
        openEvidenceRequests: 0,
        totalEvidenceRequests: 0,
        totalEvidence: 0,
        totalAssessments: 0,
        totalIssues: 0,
      },
      recentEvidenceRequests: [],
    };
  }

  const [
    totalEvidenceRequests,
    openEvidenceRequests,
    totalEvidence,
    totalAssessments,
    totalIssues,
    recentEvidenceRequests,
  ] = await Promise.all([
    prisma.evidenceRequest.count({ where: { vendorId: vendor.id } }),
    prisma.evidenceRequest.count({
      where: { vendorId: vendor.id, status: "OPEN" as any },
    }),
    prisma.evidence.count({ where: { vendorId: vendor.id } }),
    prisma.assessment.count({ where: { vendorId: vendor.id } }),
    prisma.issue.count({ where: { vendorId: vendor.id } }),
    prisma.evidenceRequest.findMany({
      where: { vendorId: vendor.id },
      orderBy: { createdAt: "desc" },
      take: 5,
      select: {
        id: true,
        label: true, // ✅ your schema uses label (not title)
        status: true,
        kind: true,
        dueAt: true,
        createdAt: true,
      },
    }),
  ]);

  return {
    linked: true,
    vendor,
    stats: {
      openEvidenceRequests,
      totalEvidenceRequests,
      totalEvidence,
      totalAssessments,
      totalIssues,
    },
    recentEvidenceRequests,
  };
}

export async function GET(req: Request) {
  try {
    // ✅ DEV BYPASS (curl)
    if (isDevBypass(req)) {
      const { vendorId, email, mode } = await getLinkedVendorIdForDev(req);

      if (!vendorId) {
        return json({
          ok: true,
          linked: false,
          vendor: null,
          stats: {
            openEvidenceRequests: 0,
            totalEvidenceRequests: 0,
            totalEvidence: 0,
            totalAssessments: 0,
            totalIssues: 0,
          },
          recentEvidenceRequests: [],
          email,
          mode,
        });
      }

      const summary = await buildSummaryForVendor(vendorId);

      return json({
        ok: true,
        ...summary,
        email,
        mode,
      });
    }

    // ✅ NORMAL AUTH (browser)
    const a = await auth();
    if (!a?.userId) return json({ ok: false, reason: "UNAUTHORIZED" }, 401);

    const u = await currentUser();
    const email = pickEmail(u);

    const link = await prisma.vendorPortalUser.findFirst({
      where: {
        OR: [{ clerkUserId: a.userId }, ...(email ? [{ email }] : [])],
      },
      select: { vendorId: true },
    });

    if (!link?.vendorId) {
      return json({
        ok: true,
        linked: false,
        vendor: null,
        stats: {
          openEvidenceRequests: 0,
          totalEvidenceRequests: 0,
          totalEvidence: 0,
          totalAssessments: 0,
          totalIssues: 0,
        },
        recentEvidenceRequests: [],
      });
    }

    const summary = await buildSummaryForVendor(link.vendorId);

    return json({
      ok: true,
      ...summary,
    });
  } catch (err: any) {
    return json(
      {
        ok: false,
        reason: "SERVER_ERROR",
        message: String(err?.message || err),
      },
      500
    );
  }
}
