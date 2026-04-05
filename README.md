# Tracx8

OBD-II 車両データロガー — ELM327 アダプタ経由で車両データを収集し、GPS・加速度データとともにリアルタイム表示・記録・アップロードする Flutter アプリと、Cloudflare Workers バックエンド。

## 構成

```
tracx8/
├── lib/          # Flutter Android アプリ
├── backend/      # Cloudflare Worker (R2 ストレージ)
└── test/         # ユニットテスト
```

---

## Android アプリ

### 必要なもの

- ELM327 Bluetooth OBD-II アダプタ（Bluetooth Classic / SPP）
- Android 8.0 (API 26) 以上の端末
- Flutter SDK 3.2 以上

### 取得するデータ

| データ | ソース | 更新頻度 |
|--------|--------|----------|
| エンジン RPM | OBD-II PID `0x0C` | ~1 Hz (全PIDのポーリングサイクル) |
| 車速 (km/h) | OBD-II PID `0x0D` | 同上 |
| スロットル開度 (%) | OBD-II PID `0x11` | 同上 |
| 冷却水温 (°C) | OBD-II PID `0x05` | 同上 |
| MAF エアフロー (g/s) | OBD-II PID `0x10` | 同上 |
| 推定燃費 (km/L) | MAF + 車速から計算 | 同上 |
| 緯度・経度・高度・速度 | GPS (高精度) | ~1 Hz |
| 加速度 X/Y/Z (m/s²) | 端末加速度センサー | ~10 Hz |

### ビルドと実行

```bash
cd tracx8
flutter pub get
flutter run
```

### 使い方

1. **ELM327 をペアリング** — Android の Bluetooth 設定から ELM327 アダプタをペアリング
2. **アプリを起動** — ペアリング済みデバイス一覧が表示される
3. **接続** — ELM327 デバイスをタップして接続
4. **ダッシュボード** — リアルタイムで OBD/GPS/加速度データが表示される
5. **ロギング開始** — 画面下部の「Start Logging」ボタンでローカル CSV 保存を開始
6. **ロギング停止** — 「Stop Logging」でファイルをクローズ

CSV ファイルはアプリの外部ストレージ (`Android/data/com.tracx8.app/files/`) に `tracx8_YYYYMMDD_HHmmss.csv` として保存されます。USB 接続でPCに取り出せます。

### バックエンドへのアップロード

1. ダッシュボード右上の **歯車アイコン** をタップ
2. バックエンド URL を入力（例: `https://tracx8-backend.your-subdomain.workers.dev`）
3. **ネットワークアイコン** で接続テスト → 「Connection successful」と表示されれば OK
4. **Save** をタップ

以降、ロギング開始時にバックエンドへもリアルタイムでデータが送信されます。

- 30行ごと、または5秒ごとにバッチ送信
- 送信失敗時は指数バックオフ (1s → 2s → 4s) で最大3回リトライ
- リトライ失敗分はバッファに保持し、次回フラッシュ時に再送
- URL が未設定の場合はローカル保存のみで動作

### CSV フォーマット

```csv
timestamp_ms,rpm,speed_kmh,throttle_pct,coolant_c,maf_gs,lat,lng,alt_m,gps_speed_ms,accel_x,accel_y,accel_z
1712345678000,1726.0000,60.0000,50.1961,70.0000,4.0000,35.681236,139.767125,40.5000,16.6667,-0.1200,0.0500,9.7800
```

値がないカラム（OBD 未接続時など）は空文字になります。

---

## バックエンド (Cloudflare Worker)

### アーキテクチャ

- **ランタイム**: Cloudflare Workers
- **ストレージ**: Cloudflare R2 (`tracx8-data` バケット)
- **データ構造**: セッションごとに `meta.json` + `data.csv` を R2 に格納

```
R2: tracx8-data/
└── sessions/{sessionId}/
    ├── meta.json    # セッションメタデータ
    └── data.csv     # ログデータ本体
```

### API

| Method | Path | 説明 |
|--------|------|------|
| `POST` | `/api/sessions` | セッション作成 |
| `POST` | `/api/sessions/:id/data` | データ行のバッチ送信 |
| `GET` | `/api/sessions` | 全セッション一覧（新しい順） |
| `GET` | `/api/sessions/:id` | セッションメタデータ取得 |
| `GET` | `/api/sessions/:id/csv` | CSV ファイルダウンロード |
| `GET` | `/api/health` | ヘルスチェック |

#### POST /api/sessions

セッションを作成する。

```bash
curl -X POST https://your-worker.workers.dev/api/sessions \
  -H "Content-Type: application/json" \
  -d '{"device_id": "my-android"}'
```

```json
{
  "sessionId": "550e8400-e29b-41d4-a716-446655440000",
  "deviceId": "my-android",
  "createdAt": "2026-04-04T12:00:00.000Z",
  "rowCount": 0,
  "lastUpdatedAt": "2026-04-04T12:00:00.000Z"
}
```

#### POST /api/sessions/:id/data

データ行をバッチ送信する。

```bash
curl -X POST https://your-worker.workers.dev/api/sessions/{sessionId}/data \
  -H "Content-Type: application/json" \
  -d '{
    "rows": [
      {
        "timestamp_ms": 1712345678000,
        "rpm": 1726,
        "speed_kmh": 60,
        "throttle_pct": 50.2,
        "lat": 35.681236,
        "lng": 139.767125,
        "accel_x": -0.12,
        "accel_y": 0.05,
        "accel_z": 9.78
      }
    ]
  }'
```

```json
{ "status": "ok", "rowCount": 1 }
```

#### GET /api/sessions/:id/csv

CSV ファイルとしてダウンロードする。

```bash
curl -O https://your-worker.workers.dev/api/sessions/{sessionId}/csv
```

### デプロイ

```bash
cd backend
npm install

# R2 バケット作成（初回のみ）
npx wrangler r2 bucket create tracx8-data

# デプロイ
npm run deploy
```

デプロイ後に表示される URL (`https://tracx8-backend.your-subdomain.workers.dev`) を Android アプリの設定画面に入力してください。

### ローカル開発

```bash
cd backend
npm run dev
# → http://localhost:8787 で起動
```

---

## ブレーキ推定について

OBD-II にはブレーキペダルの直接的な PID がありません。CSV データから以下の組み合わせで推定できます:

- **車速の減少率** (`speed_kmh` の時間微分が負)
- **スロットル開度 ≈ 0%** (`throttle_pct` が 0 に近い)
- **加速度 X 軸** (`accel_x` の変化 — 端末の設置方向に依存)

---

## 燃費計算

MAF (Mass Air Flow) と車速から瞬間燃費を推定しています:

```
燃料流量 (L/h) = MAF(g/s) × 3600 / (AFR × 燃料密度)
                = MAF × 3600 / (14.7 × 755)

燃費 (km/L) = 車速(km/h) / 燃料流量(L/h)
```

- AFR (空燃比): ガソリン = 14.7
- 燃料密度: 755 g/L

---

## ライセンス

[MIT License](./LICENSE)
