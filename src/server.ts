import express from "express";
import dotenv from "dotenv";
import voiceRoutes from "./routes/voiceRoutes";

dotenv.config();

const app = express();
app.use(express.json());

app.use("/api/voice", voiceRoutes);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 SideQuest backend running on http://localhost:${PORT}`);
});