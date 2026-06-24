# D2DW エージェント向けメモ

このリポジトリは、戸別訪問記録アプリ D2DW の静的 PWA プロトタイプです。
Claude / Codex などのエージェントは、作業前にこのファイルを最初に確認してください。

## プロジェクト構成

- メインアプリ入口（唯一のデプロイ対象）: `index.html`
- PWA 関連: `manifest.webmanifest`, `sw.js`, `icon-192.png`, `icon-512.png`, `apple-touch-icon.png`
- Supabase スキーマ・基本ポリシー: `D2DW_supabase_schema.sql`
- Google ログイン許可リスト・RLS 強化: `D2DW_allowlist.sql`
- 旧スプレッドシートからのインポートツール: `import_d2dw.py`
- インポート手順: `README_import.md`
- 要件・設計の参照元: `D2DW_要件定義_設計書.md`
- 詳細地図素材: `01nagazumi2-3detail.pdf`, `01nagazumi2-3detail.png`

現時点では package manager やビルド環境はありません。アプリは素の
HTML/CSS/JavaScript で、Leaflet と Supabase JS は CDN から読み込んでいます。

## 現在のアーキテクチャ

- フロントエンド: 単一 HTML ファイルのモバイル優先 PWA
- 地図: 広域地図は Leaflet + OpenStreetMap。区域詳細では PDF/画像由来の詳細地図を利用・予定。
- バックエンド: Supabase PostgreSQL + Auth + Realtime + RLS
- 認証: Google ログインのみ。`allowed_emails` と `is_allowed()` により RLS で許可ユーザーを制御。
- 主なデータモデル:
  - `members`: 認証ユーザーとロール
  - `blocks`: 区域
  - `places`: 戸建て、集合住宅、号室
  - `visits`: 追記型の訪問ログ
  - `assignments`: 区域担当の任意割り当て
  - `visit_rules`: 種別ごとの再訪間隔
  - `place_stats`: アプリが参照する集計ビュー

## 実装時の重要ルール

- UTF-8 を維持すること。日本語を含むファイルが多いため、PowerShell で読む場合は
  `Get-Content -Encoding UTF8` を使う。
- デプロイ対象は、ユーザーから別指示がない限り `index.html` と考える。
- 秘密情報をコミットしない。HTML 内の Supabase anon key はブラウザ公開用キーだが、service role key、PAT、OAuth secret、個人トークンは追加しない。
- 大きなリファクタは避ける。運用プロトタイプなので、現在の単一 HTML 配信を壊さない小さな変更を優先する。
- `D2DW_allowlist.sql` はスキーマ変更とは分けて扱う。このファイルは `D2DW_supabase_schema.sql` 適用後にポリシーを上書き・強化する。
- SQL ポリシーを変更する前に、基本スキーマと allowlist 側の両方を確認する。
- インポート処理を変更する前に、xlsx サンプルがある場合は `import_d2dw.py --dry-run` を実行し、生成 SQL を目視確認する。

## ローカル確認

静的アプリの簡易確認:

```powershell
python -m http.server 8000
```

その後、`http://localhost:8000/` を開きます。

アプリはブラウザグローバルと CDN の ES modules に依存しているため、JavaScript の完全な構文チェックは限定的です。
HTML/JS 変更後は、少なくともブラウザのコンソールエラーを確認してください。

インポートスクリプトの確認:

```powershell
python import_d2dw.py --ledger "OTマップ座標リスト.xlsx" --block "01長住2[OT].xlsx" --dry-run
python import_d2dw.py --ledger "OTマップ座標リスト.xlsx" --block "01長住2[OT].xlsx" --out seed.sql
```

DB 適用順:

1. Supabase SQL Editor で `D2DW_supabase_schema.sql` を実行する。
2. 許可メールを編集したうえで `D2DW_allowlist.sql` を実行する。
3. 生成した `seed.sql` を実行する。

## 決定済みのプロダクト方針

- Service Worker / localStorage によるオフライン閲覧は許可するが、古い情報での二重記録や競合を避けるため、オフライン中の訪問記録保存はブロックする。
- 前回訪問、前回面会、前回結果、不在回数、訪問可能判定などの表示値は、手動で重複保持せず `visits` / `place_stats` から導出する。
- 固定・手動ステータスは `訪問拒否`, `他言語`, `JW`, `転居・空家` など。
- 既定の `訪問可能` は、前回訪問結果と `visit_rules` の再訪間隔から自動判定する。
- 詳細地図のホットスポット座標（`map_x`, `map_y`）は後続段階の拡張。第1段階では詳細地図 + カード一覧で運用可能。

## 引き継ぎ時の参照先

- 現状と次作業は `HANDOFF.md` を読む。
- プロダクト意図と未決事項は `D2DW_要件定義_設計書.md` を読む。
- xlsx インポートに触る前に `README_import.md` を読む。
