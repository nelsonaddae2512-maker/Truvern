const { PrismaClient } = require("@prisma/client");
const p = new PrismaClient();

(async () => {
  try {
    const rows = await p.notification.findMany({
      take: 10,
      orderBy: { id: "desc" },
    });

    console.log(JSON.stringify(rows, null, 2));
  } catch (e) {
    console.error(e);
  } finally {
    await p.$disconnect();
  }
})();
