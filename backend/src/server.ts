import app from "./app";
import env from "./config/env";
import connectDb from "./config/db";

const PORT = env.port;

const start = async () => {
  try {
    await connectDb();
    app.listen(PORT, () => {
      console.log(`Server running on port ${PORT}`);
    });
  } catch (error) {
    console.error("Failed to start server", error);
    process.exit(1);
  }
};

void start();
