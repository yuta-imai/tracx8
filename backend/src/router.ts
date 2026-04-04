import { appendRows, createSession, getSessionCsv, getSessionMeta, listSessions } from './r2';
import { CreateSessionRequest, Env, IngestDataRequest } from './types';

type Handler = (
  request: Request,
  env: Env,
  params: Record<string, string>,
) => Promise<Response>;

interface Route {
  method: string;
  pattern: URLPattern;
  handler: Handler;
}

const routes: Route[] = [];

function route(method: string, path: string, handler: Handler) {
  routes.push({
    method,
    pattern: new URLPattern({ pathname: path }),
    handler,
  });
}

// ─── POST /api/sessions ─────────────────────────────────────────
route('POST', '/api/sessions', async (request, env) => {
  const body = (await request.json()) as CreateSessionRequest;
  if (!body.device_id) {
    return jsonResponse({ error: 'device_id is required' }, 400);
  }

  const sessionId = crypto.randomUUID();
  const meta = await createSession(env, sessionId, body.device_id);
  return jsonResponse(meta, 201);
});

// ─── POST /api/sessions/:id/data ────────────────────────────────
route('POST', '/api/sessions/:id/data', async (request, env, params) => {
  const sessionId = params.id;

  const existing = await getSessionMeta(env, sessionId);
  if (!existing) {
    return jsonResponse({ error: 'Session not found' }, 404);
  }

  const body = (await request.json()) as IngestDataRequest;
  if (!Array.isArray(body.rows) || body.rows.length === 0) {
    return jsonResponse({ error: 'rows array is required and must not be empty' }, 400);
  }

  // Validate that each row has timestamp_ms
  for (const row of body.rows) {
    if (typeof row.timestamp_ms !== 'number') {
      return jsonResponse({ error: 'Each row must have a numeric timestamp_ms' }, 400);
    }
  }

  const meta = await appendRows(env, sessionId, body.rows);
  return jsonResponse({ status: 'ok', rowCount: meta.rowCount });
});

// ─── GET /api/sessions/:id ──────────────────────────────────────
route('GET', '/api/sessions/:id', async (_request, env, params) => {
  const meta = await getSessionMeta(env, params.id);
  if (!meta) {
    return jsonResponse({ error: 'Session not found' }, 404);
  }
  return jsonResponse(meta);
});

// ─── GET /api/sessions/:id/csv ──────────────────────────────────
route('GET', '/api/sessions/:id/csv', async (_request, env, params) => {
  const sessionId = params.id;
  const csvObj = await getSessionCsv(env, sessionId);
  if (!csvObj) {
    return jsonResponse({ error: 'Session not found' }, 404);
  }

  return new Response(csvObj.body, {
    headers: {
      'Content-Type': 'text/csv',
      'Content-Disposition': `attachment; filename="tracx8_${sessionId}.csv"`,
    },
  });
});

// ─── GET /api/sessions ──────────────────────────────────────────
route('GET', '/api/sessions', async (_request, env) => {
  const sessions = await listSessions(env);
  // Sort newest first
  sessions.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  return jsonResponse({ sessions });
});

// ─── Health check ───────────────────────────────────────────────
route('GET', '/api/health', async () => {
  return jsonResponse({ status: 'ok', service: 'tracx8-backend' });
});

/** Match a request to a route and execute the handler. */
export function handleRequest(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);

  // CORS preflight
  if (request.method === 'OPTIONS') {
    return Promise.resolve(corsResponse());
  }

  for (const r of routes) {
    if (r.method !== request.method) continue;
    const match = r.pattern.exec(url);
    if (match) {
      const params = (match.pathname.groups ?? {}) as Record<string, string>;
      return r.handler(request, env, params).then(addCorsHeaders);
    }
  }

  return Promise.resolve(
    addCorsHeaders(jsonResponse({ error: 'Not found' }, 404)),
  );
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function corsHeaders(): Record<string, string> {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
}

function corsResponse(): Response {
  return new Response(null, { status: 204, headers: corsHeaders() });
}

function addCorsHeaders(response: Response): Response {
  const headers = new Headers(response.headers);
  for (const [key, value] of Object.entries(corsHeaders())) {
    headers.set(key, value);
  }
  return new Response(response.body, {
    status: response.status,
    headers,
  });
}
