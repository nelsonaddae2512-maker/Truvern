const { PrismaClient } = require("@prisma/client");
const p = new PrismaClient();

(async () => {
  await p.notification.deleteMany({
    where: { userId: "userA" }
  });

  console.log("Deleted all bad userA notifications");
  await p.$disconnect();
})();
