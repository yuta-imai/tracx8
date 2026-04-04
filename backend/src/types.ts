export interface Env {
  DATA_BUCKET: R2Bucket;
}

/** Metadata stored alongside each session in R2. */
export interface SessionMeta {
  sessionId: string;
  deviceId: string;
  createdAt: string;
  rowCount: number;
  lastUpdatedAt: string;
}

/** A single data row sent from the Android app. */
export interface DataRow {
  timestamp_ms: number;
  rpm?: number | null;
  speed_kmh?: number | null;
  throttle_pct?: number | null;
  coolant_c?: number | null;
  maf_gs?: number | null;
  lat?: number | null;
  lng?: number | null;
  alt_m?: number | null;
  gps_speed_ms?: number | null;
  accel_x?: number | null;
  accel_y?: number | null;
  accel_z?: number | null;
}

/** Request body for POST /api/sessions */
export interface CreateSessionRequest {
  device_id: string;
}

/** Request body for POST /api/sessions/:id/data */
export interface IngestDataRequest {
  rows: DataRow[];
}
