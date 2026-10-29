// Reads SUPABASE_URL and SUPABASE_ANON_KEY from .env (or from the host's environment
// variables, e.g. on Vercel) and writes public/config.js for the app.
const fs = require("fs");
const path = require("path");

const env = {};
const envFile = path.join(__dirname, ".env");
if (fs.existsSync(envFile)) {
  for (const line of fs.readFileSync(envFile, "utf8").split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);
    if (m && !line.trim().startsWith("#")) env[m[1]] = m[2].replace(/^["']|["']$/g, "");
  }
}
const url = process.env.SUPABASE_URL || env.SUPABASE_URL || "";
const key = process.env.SUPABASE_ANON_KEY || env.SUPABASE_ANON_KEY || "";
const publicDir = path.join(__dirname, "public");

fs.mkdirSync(publicDir, { recursive: true });

const sourceIndex = path.join(__dirname, "index.html");
const publicIndex = path.join(publicDir, "index.html");
if (fs.existsSync(sourceIndex) && !fs.existsSync(publicIndex)) {
  fs.copyFileSync(sourceIndex, publicIndex);
}

if (!url || !key || url.startsWith("YOUR_") || key.startsWith("YOUR_")) {
  console.warn("WARNING: SUPABASE_URL / SUPABASE_ANON_KEY are not set. Edit .env and run again.");
}
fs.writeFileSync(
  path.join(publicDir, "config.js"),
  "window.LMIS_CONFIG = " + JSON.stringify({ SUPABASE_URL: url, SUPABASE_ANON_KEY: key }, null, 2) + ";\n"
);
console.log("public/config.js written.");
