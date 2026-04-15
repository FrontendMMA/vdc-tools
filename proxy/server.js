import express from "express";
import { Readable } from "node:stream";

const app = express();
app.use(express.json({ limit: "50mb" }));

const PORT = Number(process.env.PORT || 8080);
const UPSTREAM_BASE_URL = process.env.UPSTREAM_BASE_URL;
const UPSTREAM_TOKEN = process.env.UPSTREAM_TOKEN;
const REQUEST_TIMEOUT_MS = Number(process.env.REQUEST_TIMEOUT_MS || 300000);
const LOG_LEVEL = process.env.LOG_LEVEL || "info";
const MAX_TOKENS_CAP = Number(process.env.MAX_TOKENS_CAP || 0);
const SMALL_MAX_TOKENS_CAP = Number(process.env.SMALL_MAX_TOKENS_CAP || 0);
const SMALL_FAST_MODEL = process.env.SMALL_FAST_MODEL || "";

const STRIP_CONTEXT_MANAGEMENT = String(process.env.STRIP_CONTEXT_MANAGEMENT || "true") === "true";
const STRIP_THINKING = String(process.env.STRIP_THINKING || "false") === "true";
const STRIP_MCP_SERVERS = String(process.env.STRIP_MCP_SERVERS || "false") === "true";
const STRIP_CONTAINER_FIELD = String(process.env.STRIP_CONTAINER_FIELD || "false") === "true";

if (!UPSTREAM_BASE_URL) throw new Error("UPSTREAM_BASE_URL is required");
if (!UPSTREAM_TOKEN) throw new Error("UPSTREAM_TOKEN is required");

function log(...args) {
  if (LOG_LEVEL !== "silent") console.log(new Date().toISOString(), ...args);
}

function sanitizeBody(body) {
  if (!body || typeof body !== "object") return body;
  const clone = structuredClone(body);
  if (STRIP_CONTEXT_MANAGEMENT) delete clone.context_management;
  if (STRIP_THINKING) delete clone.thinking;
  if (STRIP_MCP_SERVERS) delete clone.mcp_servers;
  if (STRIP_CONTAINER_FIELD) delete clone.container;
  // Apply per-model token cap
  const isSmallModel = SMALL_FAST_MODEL && clone.model === SMALL_FAST_MODEL;
  const cap = isSmallModel ? SMALL_MAX_TOKENS_CAP : MAX_TOKENS_CAP;
  if (
    Number.isFinite(cap) &&
    cap > 0 &&
    typeof clone.max_tokens === "number" &&
    clone.max_tokens > cap
  ) {
    clone.max_tokens = cap;
  }
  return clone;
}

function buildHeaders(req) {
  const headers = {
    authorization: `Bearer ${UPSTREAM_TOKEN}`,
    "content-type": "application/json",
  };
  for (const h of [
    "anthropic-version",
    "anthropic-beta",
    "x-request-id",
    "traceparent",
    "tracestate",
    "x-b3-traceid",
    "x-b3-spanid",
    "x-b3-sampled",
    "baggage",
  ]) {
    const v = req.header(h);
    if (v) headers[h] = v;
  }
  return headers;
}

async function proxyRequest(req, res, upstreamPath) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(new Error("upstream timeout")), REQUEST_TIMEOUT_MS);

  const abortForDisconnect = () => {
    if (!controller.signal.aborted) {
      controller.abort(new Error("client disconnected"));
    }
  };

  // `req.close` also fires after a normal request body is fully read.
  // For streaming responses, only abort when the client truly disconnects.
  req.on("aborted", abortForDisconnect);
  res.on("close", () => {
    if (!res.writableEnded) {
      abortForDisconnect();
    }
  });

  try {
    const body = sanitizeBody(req.body);
    const url = new URL(upstreamPath, UPSTREAM_BASE_URL).toString();
    log(req.method, upstreamPath, "model=", body?.model, "stream=", body?.stream === true);

    const upstream = await fetch(url, {
      method: req.method,
      headers: buildHeaders(req),
      body: JSON.stringify(body),
      signal: controller.signal,
    });

    res.status(upstream.status);

    const contentType = upstream.headers.get("content-type");
    if (contentType) res.setHeader("content-type", contentType);
    const cacheControl = upstream.headers.get("cache-control");
    if (cacheControl) res.setHeader("cache-control", cacheControl);
    const transferEncoding = upstream.headers.get("transfer-encoding");
    if (transferEncoding) res.setHeader("transfer-encoding", transferEncoding);

    if (!upstream.body) {
      res.end();
      return;
    }

    const nodeStream = Readable.fromWeb(upstream.body);
    nodeStream.on("error", (err) => {
      log("stream error", err?.message || String(err));
      if (!res.headersSent) {
        res.status(502).json({ error: { type: "proxy_error", message: "upstream stream error" } });
      } else {
        res.end();
      }
    });
    nodeStream.pipe(res);
  } finally {
    clearTimeout(timeout);
  }
}

app.get("/health", (_req, res) => {
  res.status(200).json({ ok: true });
});

app.post("/v1/messages", async (req, res) => {
  try {
    await proxyRequest(req, res, "/v1/messages");
  } catch (error) {
    log("proxy error /v1/messages", error?.message || String(error));
    if (!res.headersSent) {
      res.status(500).json({
        error: {
          type: "proxy_error",
          message: error instanceof Error ? error.message : String(error),
        },
      });
    } else {
      res.end();
    }
  }
});

app.post("/v1/messages/count_tokens", async (req, res) => {
  try {
    await proxyRequest(req, res, "/v1/messages/count_tokens");
  } catch (error) {
    log("proxy error /v1/messages/count_tokens", error?.message || String(error));
    if (!res.headersSent) {
      res.status(500).json({
        error: {
          type: "proxy_error",
          message: error instanceof Error ? error.message : String(error),
        },
      });
    } else {
      res.end();
    }
  }
});

app.listen(PORT, "0.0.0.0", () => {
  log(`vdc-tools proxy listening on ${PORT}`);
});
