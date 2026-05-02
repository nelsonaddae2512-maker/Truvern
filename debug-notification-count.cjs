const { PrismaClient } = require("@prisma/client");
const p = new PrismaClient();

(async () => {
  const userId = "user_36WlOBj8eYVszuYhNA0AzPzxBYS";

  const allForUser = await p.notification.count({
    where: { userId, readAt: null },
  });

  const byOrg = await p.notification.groupBy({
    by: ["organizationId"],
    where: { userId, readAt: null },
    _count: { id: true },
  });

  console.log({ allForUser, byOrg });

  await p.$disconnect();
})();
