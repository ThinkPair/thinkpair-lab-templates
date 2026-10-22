async function withRequestOriginMetadata(request, response) {
  const isHtml = response.headers.get("content-type")?.includes("text/html");
  if (request.method !== "GET" || !response.ok || !isHtml) return response;

  const origin = new URL(request.url).origin;
  const html = await response.text();
  const headers = new Headers(response.headers);
  headers.delete("content-length");

  return new Response(html.replace('content="/og.png"', `content="${origin}/og.png"`), {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

export default {
  async fetch(request, env) {
    const response = await env.ASSETS.fetch(request);
    const acceptsHtml = request.headers.get("accept")?.includes("text/html");

    if (response.status !== 404 || !acceptsHtml || !["GET", "HEAD"].includes(request.method)) {
      return withRequestOriginMetadata(request, response);
    }

    const indexUrl = new URL(request.url);
    indexUrl.pathname = "/index.html";
    indexUrl.search = "";
    const fallback = await env.ASSETS.fetch(new Request(indexUrl, request));
    return withRequestOriginMetadata(request, fallback);
  },
};
