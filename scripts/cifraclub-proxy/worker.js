// Cloudflare Worker that fetches CifraClub pages on behalf of the app.
//
// Vercel's IP ranges are blocked by CifraClub's bot protection (403); requests
// from Cloudflare's network are usually let through.
//
// Deploy: create a Worker in the Cloudflare dashboard (or `wrangler deploy`), paste this
// file, and set a secret named PROXY_SECRET. Then set these env vars in Vercel:
//   CIFRACLUB_PROXY_URL    = https://<your-worker>.workers.dev
//   CIFRACLUB_PROXY_SECRET = <same value as PROXY_SECRET>

const ALLOWED_HOSTS = new Set(["cifraclub.com", "www.cifraclub.com", "m.cifraclub.com"])

const BROWSER_USER_AGENT =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

export default {
  async fetch(request, env) {
    if (!env.PROXY_SECRET || request.headers.get("x-proxy-secret") !== env.PROXY_SECRET) {
      return new Response("Forbidden", { status: 403 })
    }

    const target = new URL(request.url).searchParams.get("url")
    let targetUrl
    try {
      targetUrl = new URL(target)
    } catch {
      return new Response("Bad request", { status: 400 })
    }

    if (targetUrl.protocol !== "https:" || !ALLOWED_HOSTS.has(targetUrl.hostname)) {
      return new Response("Host not allowed", { status: 400 })
    }

    const upstream = await fetch(targetUrl.href, {
      headers: {
        "User-Agent": BROWSER_USER_AGENT,
        Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9,pt-BR;q=0.8,es;q=0.7"
      },
      // Pass redirects back to the app so it can re-validate each hop.
      redirect: "manual"
    })

    const headers = new Headers()
    const location = upstream.headers.get("location")
    if (location) headers.set("location", location)
    const contentType = upstream.headers.get("content-type")
    if (contentType) headers.set("content-type", contentType)

    return new Response(upstream.status >= 300 && upstream.status < 400 ? null : upstream.body, {
      status: upstream.status,
      headers
    })
  }
}
