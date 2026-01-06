// tests/integrity.test.ts
import test from "node:test";
import assert from "node:assert/strict";
import { computeVendorSealedHash, vendorSealPayload } from "../lib/integrity";

test("vendor seal payload is stable", () => {
  const sealedAt = new Date("2025-01-01T00:00:00.000Z");
  const payload = vendorSealPayload({
    id: 1,
    organizationId: 1,
    name: "Acme Security",
    category: "Security",
    ogSlug: "acme-security",
    sealedAt,
  });

  assert.equal(payload.version, 1);
  assert.equal(payload.vendor.ogSlug, "acme-security");
  assert.equal(payload.vendor.sealedAt, "2025-01-01T00:00:00.000Z");
});

test("computeVendorSealedHash is deterministic", () => {
  const sealedAt = new Date("2025-01-01T00:00:00.000Z");

  const a = computeVendorSealedHash({
    id: 1,
    organizationId: 1,
    name: "Acme Security",
    category: "Security",
    ogSlug: "acme-security",
    sealedAt,
  });

  const b = computeVendorSealedHash({
    id: 1,
    organizationId: 1,
    name: "Acme Security",
    category: "Security",
    ogSlug: "acme-security",
    sealedAt,
  });

  assert.equal(a, b);
  assert.match(a, /^[a-f0-9]{64}$/i);
});

test("hash changes if payload changes", () => {
  const sealedAt = new Date("2025-01-01T00:00:00.000Z");

  const base = computeVendorSealedHash({
    id: 1,
    organizationId: 1,
    name: "Acme Security",
    category: "Security",
    ogSlug: "acme-security",
    sealedAt,
  });

  const changed = computeVendorSealedHash({
    id: 1,
    organizationId: 1,
    name: "Acme Security v2",
    category: "Security",
    ogSlug: "acme-security",
    sealedAt,
  });

  assert.notEqual(base, changed);
});
