import { defineConfig } from "vite";
import gleam from "vite-gleam";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  plugins: [gleam(), tailwindcss()],
  build: { sourcemap: true },
  server: {
    // The SPA calls the API same-origin under `/api`; in dev we proxy that to
    // the Bun API server (`bun --watch api/index.ts`, default :3000). In prod
    // both are served from the same origin, so no CORS anywhere.
    proxy: { "/api": "http://localhost:3000" },
  },
});
