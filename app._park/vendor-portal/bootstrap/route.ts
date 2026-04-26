// app/api/vendor-portal/bootstrap/route.ts
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

export async function GET(req: Request) {
  try {
    // ✅ DEV BYPASS (for curl testing)
    if (isDevBypass(req)) {
      const email = (req.headers.get("x-dev-email") || "").trim().toLowerCase() || null;

      const link = await prisma.vendorPortalUser.findFirst({
        where: email ? { email } : {},
        orderBy: { id: "asc" },
        select: { id: true, vendorId: true, email: true },
      });

      if (!link?.vendorId) {
        return json({
          ok: true,
          linked: false,
          vendorId: null,
          email,
          mode: "dev-bypass",
        });
      }

      return json({
        ok: true,
        linked: true,
        vendorId: link.vendorId,
        email: link.email ?? email,
        mode: "dev-bypass",
      });
    }

    // ✅ NORMAL AUTH (browser)
    const a = await auth();
    if (!a?.userId) {
      return json(
        {
          ok: false,
          reason: "UNAUTHORIZED",
          redirect: `/sign-in?redirect_url=${encodeURIComponent("/vendor-portal")}`,
        },
        401
      );
    }

    const user = await currentUser();
    const email = pickEmail(user);

    const link = await prisma.vendorPortalUser.findFirst({
      where: {
        OR: [
          { clerkUserId: a.userId },
          ...(email ? [{ email }] : []),
        ],
      },
      select: { id: true, vendorId: true, email: true },
    });

    if (!link?.vendorId) {
      return json({ ok: true, linked: false, vendorId: null, email });
    }

    return json({ ok: true, linked: true, vendorId: link.vendorId, email: link.email ?? email });
  } catch (err: any) {
    return json(
      { ok: false, reason: "SERVER_ERROR", message: String(err?.message || err) },
      500
    );
  }
}
