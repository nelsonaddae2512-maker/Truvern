const { PrismaClient } = require("@prisma/client");
const p = new PrismaClient();

(async () => {
  await p.notification.updateMany({
    where: { userId: { not: { startsWith: "user_" } } },
    data: { userId: "user_YOUR_REAL_ID" } // replace with your Clerk ID
  });

  console.log("patched");
  await p.$disconnect();
})();
