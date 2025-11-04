/*---------------------------------------
|
| Modules
|
----------------------------------------*/ 

import dotenv from "dotenv";
import express from "express";
import axios from "axios";
import crypto from "crypto";
import { Client, GatewayIntentBits } from "discord.js";

dotenv.config({path: ['.env']});

/*---------------------------------------
|
| Varaibles & Objects
|
----------------------------------------*/

const app = express();
const PORT = process.env.PORT;

/*---------------------------------------
|
| Functions
|
----------------------------------------*/

// Verify GitHub HMAC signature
function verifyGitHubSignature(req, res, buf) {
    const secret = process.env.GITHUB_WEBHOOK_SECRET;
    if (!secret) return;

    const signature = req.headers["x-hub-signature-256"];
    if (!signature) return;

    const hmac = crypto.createHmac("sha256", secret);
    hmac.update(buf);
    const expected = "sha256=" + hmac.digest("hex");

    const sigBuf = Buffer.from(signature);
    const expBuf = Buffer.from(expected);

    if (sigBuf.length !== expBuf.length || !crypto.timingSafeEqual(sigBuf, expBuf)) {
        throw new Error("Invalid GitHub signature");
    }
}

app.use(express.json({ verify: verifyGitHubSignature }));

/*---------------------------------------
|
| HTTP Requests
|
----------------------------------------*/

// GET Request - https://domain.tld

app.get("/", (req, res) => res.send("GitHub → Discord relay active"));


// POST Request - https://domain.tld/github

app.post("/github", async (req, res) => {
    const event = req.headers["x-github-event"];
    const payload = req.body;

    try {
        let content = "";

        if (event === "push") {
            const repo = payload.repository.full_name;
            const pusher = payload.pusher?.name || "unknown";
            const branch = payload.ref.replace("refs/heads/", "");

            content += `**${repo}** updated by **${pusher}** on branch \`${branch}\`\n`;

            if (Array.isArray(payload.commits) && payload.commits.length > 0) {
                const commits = payload.commits
                    .map(c => `• [\`${c.id.slice(0, 7)}\`](${c.url}) ${c.message.split("\n")[0]} — ${c.author.name}`)
                    .join("\n");

                content += commits;
            } else {
                content += "No commits found.";
            }

            if (payload.compare) {
                content += `\n\n[View changes](${payload.compare})`;
            }
        } else {
            const repo = payload.repository?.full_name || "unknown repository";
            content = `GitHub event **${event}** from **${repo}**`;
            if (payload.action) content += ` (${payload.action})`;
        }

        await axios.post(process.env.DISCORD_WEBHOOK_URL, { content });
        console.log(`Posted ${event} event to Discord`);
        res.sendStatus(200);
    } catch (err) {
        console.error("Error posting to Discord:", err.message);
        res.sendStatus(500);
    }
});

app.listen(PORT, () => {
    console.log(`Listening on port ${PORT}`);
});

/*---------------------------------------
|
| Registering Client to Login Bot
|
----------------------------------------*/

// Declare client and register intent
const client = new Client({
  intents: [GatewayIntentBits.Guilds],
})

// Login
client.login(process.env.BOT_TOKEN);