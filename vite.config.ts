import { defineConfig } from "vite";
import gleam from "vite-gleam";

export default defineConfig({
  plugins: [gleam()],
  build: { sourcemap: true },
});
