import { DataRow, Env, SessionMeta } from './types';

const CSV_HEADER =
  'timestamp_ms,rpm,speed_kmh,throttle_pct,coolant_c,maf_gs,' +
  'lat,lng,alt_m,gps_speed_ms,accel_x,accel_y,accel_z';

/** R2 key for session metadata JSON. */
function metaKey(sessionId: string): string {
  return `sessions/${sessionId}/meta.json`;
}

/** R2 key for session CSV data. */
function dataKey(sessionId: string): string {
  return `sessions/${sessionId}/data.csv`;
}

/** Create a new session: write initial metadata and CSV header. */
export async function createSession(
  env: Env,
  sessionId: string,
  deviceId: string,
): Promise<SessionMeta> {
  const now = new Date().toISOString();
  const meta: SessionMeta = {
    sessionId,
    deviceId,
    createdAt: now,
    rowCount: 0,
    lastUpdatedAt: now,
  };

  await Promise.all([
    env.DATA_BUCKET.put(metaKey(sessionId), JSON.stringify(meta), {
      httpMetadata: { contentType: 'application/json' },
    }),
    env.DATA_BUCKET.put(dataKey(sessionId), CSV_HEADER + '\n', {
      httpMetadata: { contentType: 'text/csv' },
    }),
  ]);

  return meta;
}

/** Get session metadata. Returns null if not found. */
export async function getSessionMeta(
  env: Env,
  sessionId: string,
): Promise<SessionMeta | null> {
  const obj = await env.DATA_BUCKET.get(metaKey(sessionId));
  if (!obj) return null;
  return (await obj.json()) as SessionMeta;
}

/** Append data rows to the session's CSV file and update metadata. */
export async function appendRows(
  env: Env,
  sessionId: string,
  rows: DataRow[],
): Promise<SessionMeta> {
  const meta = await getSessionMeta(env, sessionId);
  if (!meta) throw new Error('Session not found');

  // Read existing CSV
  const existing = await env.DATA_BUCKET.get(dataKey(sessionId));
  const existingText = existing ? await existing.text() : CSV_HEADER + '\n';

  // Convert rows to CSV lines
  const csvLines = rows.map(rowToCsv).join('\n');
  const newCsv = existingText + csvLines + '\n';

  // Update metadata
  meta.rowCount += rows.length;
  meta.lastUpdatedAt = new Date().toISOString();

  await Promise.all([
    env.DATA_BUCKET.put(dataKey(sessionId), newCsv, {
      httpMetadata: { contentType: 'text/csv' },
    }),
    env.DATA_BUCKET.put(metaKey(sessionId), JSON.stringify(meta), {
      httpMetadata: { contentType: 'application/json' },
    }),
  ]);

  return meta;
}

/** Get the CSV data for a session as a ReadableStream. */
export async function getSessionCsv(
  env: Env,
  sessionId: string,
): Promise<R2ObjectBody | null> {
  return env.DATA_BUCKET.get(dataKey(sessionId));
}

/** List all sessions by scanning meta.json files. */
export async function listSessions(env: Env): Promise<SessionMeta[]> {
  const listed = await env.DATA_BUCKET.list({ prefix: 'sessions/', delimiter: '/' });

  const sessions: SessionMeta[] = [];
  for (const prefix of listed.delimitedPrefixes) {
    // prefix looks like "sessions/abc123/"
    const sessionId = prefix.replace('sessions/', '').replace('/', '');
    const meta = await getSessionMeta(env, sessionId);
    if (meta) sessions.push(meta);
  }

  return sessions;
}

function fmt(v: number | null | undefined): string {
  if (v == null) return '';
  return Number.isInteger(v) ? v.toString() : v.toFixed(4);
}

function rowToCsv(row: DataRow): string {
  return [
    row.timestamp_ms.toString(),
    fmt(row.rpm),
    fmt(row.speed_kmh),
    fmt(row.throttle_pct),
    fmt(row.coolant_c),
    fmt(row.maf_gs),
    fmt(row.lat),
    fmt(row.lng),
    fmt(row.alt_m),
    fmt(row.gps_speed_ms),
    fmt(row.accel_x),
    fmt(row.accel_y),
    fmt(row.accel_z),
  ].join(',');
}
