const { PrismaClient } = require("@prisma/client");
const p = new PrismaClient();

(async () => {
  try {
    const orgId = 2;

    const rows = await p.truvernCreditLedgerEntry.findMany({
      where: { organizationId: orgId, status: "POSTED" },
      select: { entryType: true, quantity: true },
    });

    const s = {
      purchase: 0,
      grant: 0,
      reservation: 0,
      release: 0,
      consumption: 0,
      adjustment: 0,
      refund: 0,
      reversal: 0,
    };

    for (const r of rows) {
      const t = String(r.entryType || "").toLowerCase();
      s[t] = (s[t] || 0) + Number(r.quantity || 0);
    }

    const available =
      s.purchase + s.grant + s.refund + s.adjustment - s.reservation - s.consumption;

    console.log("Ledger totals:", s);
    console.log("Expected available:", available);
  } catch (e) {
    console.error(e);
  } finally {
    await p.$disconnect();
  }
})();
