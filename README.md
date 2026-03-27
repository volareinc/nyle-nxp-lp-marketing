# nyle-nxp-lp-marketing

NYLE X PARTNERS マーケティングLP サイト

## 概要

ナイル株式会社が運営する NYLE X PARTNERS のマーケティングランディングページです。

## URL構成

| ページ | URL |
|--------|-----|
| トップページ（リダイレクト） | `https://nxp.nyle.co.jp/` → `/marketing/` |
| サービスページ | `https://nxp.nyle.co.jp/marketing/` |
| 問い合わせページ | `https://nxp.nyle.co.jp/contact/` |
| 問い合わせ完了ページ | `https://nxp.nyle.co.jp/contact/complete/` |
| 資料DLページ（リダイレクト） | `https://nxp.nyle.co.jp/ebook/` → `/ebook/marketing/` |
| マーケティング資料DL | `https://nxp.nyle.co.jp/ebook/marketing/` |
| 資料DL完了ページ | `https://nxp.nyle.co.jp/ebook/complete/` |
| 人材募集ページ | `https://nxp.nyle.co.jp/entry/` |
| 人材募集フォーム | `https://nxp.nyle.co.jp/entry/form/` |
| 人材募集完了ページ | `https://nxp.nyle.co.jp/entry/complete/` |

## ディレクトリ構造

```
nyle-nxp-lp-marketing/
├── index.html                    # ルートリダイレクト（/ → /marketing/）
├── 404.html                      # 404エラーページ
├── assets/                       # 共通アセット
│   ├── img/                      # 画像（47ファイル）
│   ├── css/                      # スタイルシート（2ファイル）
│   └── js/                       # JavaScript（1ファイル）
├── marketing/                    # サービスページ
│   └── index.html
├── contact/                      # 問い合わせ
│   ├── index.html
│   └── complete/
│       └── index.html
├── ebook/                        # 資料DL
│   ├── index.html               # リダイレクト（/ebook/ → /ebook/marketing/）
│   ├── marketing/
│   │   └── index.html
│   └── complete/
│       └── index.html
├── entry/                        # 人材募集
│   ├── index.html
│   ├── form/
│   │   └── index.html
│   ├── complete/
│   │   └── index.html
│   └── assets/                  # エントリー固有アセット
├── ai/                           # AI関連LP（旧nyle-nxp-lpリポジトリ）
│   ├── contact/                 # AI問い合わせ
│   ├── css/                     # スタイルシート
│   ├── images/                  # 画像
│   ├── img/                     # 画像
│   └── js/                      # JavaScript
├── config/                       # インフラ設定
│   ├── nginx/
│   │   └── nxp.conf
│   ├── s3-cloudfront/
│   │   ├── cloudfront-function-redirect.js
│   │   ├── cloudfront-distribution.json
│   │   └── s3-bucket-policy.json
│   └── redirect-templates/
│       ├── ebook-index.html
│       └── root-index.html
└── docs/                         # ドキュメント

```

## 移行履歴

- **旧ドメイン**: `https://x.seohacks.net/`
- **新ドメイン**: `https://nxp.nyle.co.jp/`
- **旧リポジトリ**: `volareinc/nxp-seohacks`
- **新リポジトリ**: `volareinc/nyle-nxp-lp-marketing`

### 主な変更点

1. ドメイン変更：`x.seohacks.net` → `nxp.nyle.co.jp`
2. パス変更：
   - `/` → `/marketing/`
   - `/nxp-contact/` → `/contact/`
   - `/nxp-service/` → `/ebook/marketing/`
   - `/entry/form.html` → `/entry/form/`
3. アセット統合：`img/`, `css/`, `js/` → `assets/` 配下に統合

## デプロイ

詳細なCI/CD構成は [`docs/cicd-github-actions.md`](docs/cicd-github-actions.md) を参照してください。

| ブランチ | 環境 | URL |
|---------|------|-----|
| `develop` | dev | `https://dev.nxp.nyle.co.jp` |
| `main` | prd | `https://nxp.nyle.co.jp` |

### 開発環境

```bash
# ローカルサーバー起動（Python）
python3 -m http.server 8000

# または、Node.js
npx http-server -p 8000
```

ブラウザで `http://localhost:8000/` にアクセスして動作確認。

### 本番環境

- **インフラ**: EC2 + nginx + ALB
- **ドメイン**: `nxp.nyle.co.jp`
- **デプロイ方式**: GitHub Actions + S3 + SSM SendCommand

## 技術スタック

- **HTML5 / CSS3 / JavaScript**
- **jQuery 3.6.0**
- **HubSpot Forms** (フォーム連携)
- **Google Tag Manager** (GTM-K7CPD87F)

## 注意事項

- 旧ドメイン（x.seohacks.net）から新ドメインへの301リダイレクトを設定すること
- Google Search Console でアドレス変更を申請すること
- 旧サイトは最低1ヶ月間は維持し、アクセスを監視すること

## ライセンス

Copyright © Nyle Inc.
