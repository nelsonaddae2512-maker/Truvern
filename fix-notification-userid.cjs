const { PrismaClient } = require("@prisma/client");
const p = new PrismaClient();

(async () => {
  const realUserId = "user_36WlOBj8eYVszuYhNA0AzPzxBYS";

  await p.notification.updateMany({
    where: {
      userId: { in: ["user_YOUR_REAL_ID", "PASTE_REAL_CLERK_USER_ID_HERE"] },
    },
    data: {
      userId: realUserId,
    },
  });

  console.log("updated notifications to", realUserId);
  await p.$disconnect();
})();
