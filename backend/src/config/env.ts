import dotenv from "dotenv";

dotenv.config();

const DEFAULT_PORT = 3000;
const port = Number(process.env.PORT) || DEFAULT_PORT;

export const env = {
  port,
};

export default env;
