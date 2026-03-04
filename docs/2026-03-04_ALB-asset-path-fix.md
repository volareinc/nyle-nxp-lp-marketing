# ALBリスナールール修正レポート

**日付:** 2026-03-04
**対象環境:** dev.nxp.nyle.co.jp
**ステータス:** ✅ 完了

## 問題概要

### 発生していた現象
- https://dev.nxp.nyle.co.jp/marketing/ にアクセスすると、CSSや画像ファイルが読み込まれない
- 開発者ツールで確認すると、`/assets/` 配下のファイルが301リダイレクトされていた

### 原因
ALBのリスナールールが、**すべてのパス**（`/assets/*` を含む）を `/marketing/` にリダイレクトする設定になっていた。

#### リクエストフロー（修正前）
```
1. ブラウザ: https://dev.nxp.nyle.co.jp/marketing/ を表示
2. HTML解析: ../assets/css/style.css を読み込もうとする
3. ブラウザ: https://dev.nxp.nyle.co.jp/assets/css/style.css にリクエスト
4. ALB: 301リダイレクト → https://dev.nxp.nyle.co.jp/marketing/ ❌
5. CSSが読み込めない
```

---

## 解決方法

### ALBリスナールールの修正

#### 修正内容
**新規ルール（優先度: 高）を追加:**

**条件（OR）:**
- `/assets/*`
- `/includes/*`
- `/healthz`
- `/404.html`
- `/*.ico`
- `/*.webp`
- `/*.svg`

**アクション:**
- ターゲットグループに転送（リダイレクトしない）

**既存のリスナールール:**
- `/entry/*`, `/contact/*`, `/ebook/*`, `/marketing/*` は既に個別ルールで設定済みのため、新規ルールには追加不要

---

## 動作確認結果

### 修正後の確認
```bash
# 1. ルートのリダイレクト確認
curl -I https://dev.nxp.nyle.co.jp/
→ 301 → /marketing/ ✅

# 2. CSSファイルの取得確認
curl -I https://dev.nxp.nyle.co.jp/assets/css/style.css
→ 200 OK ✅（修正前は301）

# 3. 画像ファイルの取得確認
curl -I https://dev.nxp.nyle.co.jp/assets/img/logo.svg
→ 200 OK ✅

# 4. includesファイルの取得確認
curl -I https://dev.nxp.nyle.co.jp/includes/footer.html
→ 200 OK ✅
```

### ブラウザでの確認
- https://dev.nxp.nyle.co.jp/marketing/ にアクセス
- CSS、画像、JavaScriptがすべて正常に読み込まれることを確認 ✅

---

## 環境情報

### サーバー構成
- **ALB:** HTTPS (443) → HTTP (80)
- **EC2:** 10.200.52.107
- **nginx:** 1.28.2
- **ドキュメントルート:** `/var/www/dev.nxp.nyle.co.jp/` → `/var/www/nyle-nxp-lp-marketing/` (シンボリックリンク)
- **Basic認証:** ユーザー名 `admin`, パスワード `password`

### ディレクトリ構造
```
/var/www/nyle-nxp-lp-marketing/
├── index.html (リダイレクト用)
├── assets/
│   ├── css/
│   ├── img/
│   └── js/
├── marketing/
│   └── index.html
├── contact/
│   └── index.html
├── ebook/
│   └── marketing/
│       └── index.html
├── entry/
├── includes/
└── 404.html
```

### HTMLファイルのパス指定
各HTMLファイルでは相対パスでassetsを参照：
- `marketing/index.html` → `../assets/css/style.css`
- `contact/index.html` → `../assets/css/style.css`
- `ebook/marketing/index.html` → `../../assets/css/style.css`

---

## 今後の注意点

### 本番環境への適用
本番環境（nxp.nyle.co.jp）のALBにも、同様のリスナールール修正が必要です。

### 追加のパスがある場合
今後、新しいディレクトリやファイルを追加する場合：
- 静的コンテンツ（CSS, JS, 画像など）は `/assets/` に配置
- ページコンテンツは個別のディレクトリ（`/service/`, `/about/` など）に配置
- 個別ディレクトリは必要に応じてALBリスナールールに追加

### nginx設定
`/etc/nginx/conf.d/10-nxp-dev.conf` では適切に設定されており、問題なし：
```nginx
location ^~ /assets/ {
    add_header Cache-Control "public, max-age=2592000, immutable";
    access_log off;
    try_files $uri =404;
}
```

---

## まとめ

**原因:** ALBのリスナールールが広範囲にリダイレクトを適用
**解決:** `/assets/*` などの静的コンテンツパスをリダイレクト対象から除外
**結果:** すべてのリソースが正常に読み込まれるようになった

**作業時間:** 約30分
**ダウンタイム:** なし（設定変更のみ）
