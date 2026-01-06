// tests/_integrity.mjs
import crypto from "node:crypto";

export function vendorSealPayload(v) {
  return {
    version: 1,
    vendor: {
      id: v.id,
      organizationId: v.organizationId,
      name: v.name,
      category: v.category ?? null,
      ogSlug: v.ogSlug,
      sealedAt: v.sealedAt.toISOString(),
    },
  };
}

export function sha256HexFromJson(obj) {
  return crypto.createHash("sha256").update(JSON.stringify(obj)).digest("hex");
}

export function computeVendorSealedHash(v) {
  return sha256HexFromJson(vendorSealPayload(v));
}
