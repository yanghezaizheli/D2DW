# D2DW 引き継ぎメモ

最終更新: 2026-06-24

## 現在の状態

D2DW は、戸別訪問記録を管理するための静的 PWA プロトタイプです。
現在の実行対象は `index.html` で、`manifest.webmanifest`, `sw.js`, 各種アイコンにより PWA として動作します。
ブラウザから Supabase に直接接続し、HTML 内の公開用 anon key を使っています。

このリポジトリには、Supabase のセットアップ SQL、許可リスト/RLS 強化 SQL、旧 Google スプレッドシート由来の xlsx を Supabase 用 seed SQL に変換するスクリプトも含まれています。

Node / Vite / React などのビルド環境は現時点ではありません。将来のタスクで明示的に導入しない限り、静的ファイルとして扱ってください。

## デプロイ・実行時の前提

- 公開入口ファイル: `index.html`
- ホスティング先は Vercel などの静的ホスティング想定
- アプリに設定済みの Supabase URL:
  `https://zjbceaqykutzwnvztryu.supabase.co`
- Supabase Auth は Google ログインを使う想定
- 実際のアクセス制御は `D2DW_allowlist.sql` と `allowed_emails` テーブルに依存するため、実利用前に許可メールを登録すること

## 主なファイル

| ファイル | 役割 |
|---|---|
| `index.html` | メインの静的 PWA アプリ |
| `D2DW_app.html` | 重複/別名のアプリ成果物。編集前に扱いを確認する |
| `D2DW_prototype.html` | 以前のプロトタイプ・参照用 |
| `D2DW_supabase_schema.sql` | テーブル、ビュー、基本 RLS、Realtime 設定 |
| `D2DW_allowlist.sql` | `allowed_emails`, `is_allowed()`, 強化ポリシー |
| `import_d2dw.py` | 旧 xlsx から Supabase seed SQL へ変換 |
| `README_import.md` | インポート手順と移行時の注意 |
| `D2DW_要件定義_設計書.md` | 要件・設計の参照文書 |
| `assets/images/01nagazumi2-*.png` | レンダリング済み詳細地図画像 |

## ローカルでの起動

リポジトリ直下で実行:

```powershell
python -m http.server 8000
```

その後、`http://localhost:8000/` を開きます。

Leaflet と Supabase JS を CDN から読み込むため、ローカル確認にもネットワーク接続が必要です。
まずはブラウザコンソールのエラー確認が一番早いスモークテストになります。

## データベース適用順

1. `D2DW_supabase_schema.sql` を適用する。
2. 実際の許可メールを追加・差し替えたうえで `D2DW_allowlist.sql` を適用する。
3. xlsx 元データがある場合は `import_d2dw.py` で `seed.sql` を生成して適用する。

インポートの dry-run 例:

```powershell
python import_d2dw.py --ledger "OTマップ座標リスト.xlsx" --block "01長住2[OT].xlsx" --dry-run
```

dry-run の件数・警告を確認してから seed を生成:

```powershell
python import_d2dw.py --ledger "OTマップ座標リスト.xlsx" --block "01長住2[OT].xlsx" --out seed.sql
```

## 決定済みのプロダクト方針

- PWA は記録保存についてオンライン前提。オフライン時はキャッシュ済みデータの閲覧はできるが、訪問記録の保存はブロックする。
- 前回訪問、前回面会、不在回数、前回結果、次回訪問可能日、訪問可能判定などは訪問ログから導出する。
- `place_stats` が、戸別状態を読むための中心的なビュー。
- `visit_rules` は再訪間隔を管理する。
  - LDR: 不在/投函/会えた = 30/30/90 日
  - ST-M, EV-M, AL-M: 不在/投函/会えた = 90/30/180 日
- 種別コードの正式な意味や ST-M の間隔値は、設計書ではまだ要確認扱い。

## 既知の注意点

- `index.html` と `D2DW_app.html` は重複しているように見える。両方がまだ使われている場合、一方だけ直してもう一方を忘れないこと。
- PowerShell では、日本語ファイルが UTF-8 指定なしだと文字化けすることがある。
- `D2DW_allowlist.sql` は `D2DW_supabase_schema.sql` で作った RLS ポリシーを変更する。ポリシー変更時は必ず両方を見る。
- 旧スプレッドシートはレイアウトが不規則。生成された seed SQL は、dry-run と目視確認なしに信用しない。
- 詳細地図のピン座標（`map_x`, `map_y`）は未整備。現実的には、当面カード一覧での運用に依存する可能性がある。
- Supabase service role key、API PAT、OAuth secret などの秘密情報をリポジトリに追加しない。

## 次にやるとよいこと

1. `D2DW_app.html` を残すのか、`index.html` に一本化するのか決める。
2. デプロイ済みアプリが現在の Supabase スキーマ・allowlist と整合しているか確認する。
3. `D2DW_allowlist.sql` に実際の許可メールを追加する、または Supabase 上で直接登録する。
4. 実際の台帳/区域 xlsx で import の dry-run を実行し、元シートの件数と比較する。
5. 手動テスト項目を追加する。例: ログイン、区域一覧、区域詳細、号室一覧、訪問記録保存、リアルタイム更新、オフライン閲覧。
