// middleware.ts
import { clerkMiddleware, createRouteMatcher } from "@clerk/nextjs/server";
import { NextResponse } from "next/server";

const ROBOTS_VALUE = "noindex, nofollow, noarchive, nosnippet";
const SITE_ORIGIN = "https://www.truvern.com";

function withNoIndex<T extends NextResponse>(res: T): T {
  res.headers.set("X-Robots-Tag", ROBOTS_VALUE);
  res.headers.set("Cache-Control", "no-store");
  return res;
}

function withCanonical<T extends NextResponse>(res: T, canonicalPath: string): T {
  res.headers.set("Link", `<${SITE_ORIGIN}${canonicalPath}>; rel="canonical"`);
  return res;
}

const isPublicRoute = createRouteMatcher([
  "/",
  "/pricing(.*)",
  "/contact(.*)",
  "/features(.*)",
  "/trust-network(.*)",
  "/assessment/demo(.*)",
  "/sign-in(.*)",
  "/sign-up(.*)",
  "/sso-callback(.*)",

  "/vendor-assessment(.*)",
  "/api/vendor-assessment/(.*)",
  "/api/public/(.*)",

  "/api/webhooks/(.*)",
  "/api/stripe/(.*)",

  "/select-org(.*)",
]);

const isPublicButNoIndexRoute = createRouteMatcher([
  "/vendor-assessment(.*)",
  "/api/vendor-assessment/(.*)",
  "/api/public/(.*)",
]);

const isApiJsonRoute = createRouteMatcher([
  "/api/notifications/(.*)",
]);

export default clerkMiddleware(async (auth, req) => {
  const requestHeaders = new Headers(req.headers);
  requestHeaders.set("x-pathname", req.nextUrl.pathname);

  const res = NextResponse.next({
    request: {
      headers: requestHeaders,
    },
  });

  if (process.env.NODE_ENV !== "production") {
    res.headers.set("x-truvern-mw", "1");
  }

  const pathname = req.nextUrl.pathname;

  if (pathname === "/") return withCanonical(res, "/");
  if (pathname === "/pricing") return withCanonical(res, "/pricing");
  if (pathname === "/trust-network") return withCanonical(res, "/trust-network");

  // Public board packets must be token-only. No bare public /board-packet page.
  if (pathname === "/board-packet" || pathname.startsWith("/board-packet/")) {
    const token = req.nextUrl.searchParams.get("token");
    if (token?.trim()) return withNoIndex(res);
  }

  if (isPublicRoute(req)) {
    if (isPublicButNoIndexRoute(req)) return withNoIndex(res);
    return withNoIndex(res);
  }

  const { userId } = await auth();

  if (!userId) {
    if (isApiJsonRoute(req)) {
      return withNoIndex(
        NextResponse.json({ ok: false, count: 0 }, { status: 401 }),
      );
    }

    return withNoIndex(
      NextResponse.redirect(
        new URL(`/sign-in?redirect_url=${encodeURIComponent(req.url)}`, req.url),
      ),
    );
  }

  return withNoIndex(res);
});

export const config = {
  matcher: [
    "/((?!_next|.*\\..*).*)",
    "/(api|trpc)(.*)",
  ],
};