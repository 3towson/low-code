import { serveDir } from "jsr:@std/http/file-server";

const PORT = 8080;
console.log(`Local web server running at http://localhost:${PORT}`);

Deno.serve({ port: PORT }, (req) => {
  return serveDir(req, {
    fsRoot: "app/build/web",
    showIndex: true,
    quiet: true,
  });
});
