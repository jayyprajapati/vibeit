import mongoose from "mongoose";
import env from "./env";

export const connectDb = async (): Promise<void> => {
  const uri = env.mongoUri;

  if (!uri) {
    throw new Error("MongoDB connection string is missing");
  }

  await mongoose.connect(uri, {
    serverSelectionTimeoutMS: 5000,
  });

  console.log("Connected to MongoDB");
};

export default connectDb;
