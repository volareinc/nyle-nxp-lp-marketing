# 末尾スラッシュ正規化対応レポート

**日付:** 2026-03-05
**対象環境:** dev.nxp.nyle.co.jp
**ステータス:** 🔄 実装中

## 問題概要

### 発生していた現象
末尾スラッシュなしのURLが `/marketing/` にリダイレクトされていた：

| URL | 期待される動作 | 実際の動作 | 結果 |
|-----|--------------|-----------|------|
| `/marketing` | → `/marketing/` | → `/marketing/` | ✅ OK |
| `/contact` | → `/contact/` | → `/marketing/` | ❌ NG |
| `/entry` | → `/entry/` | → `/marketing/` | ❌ NG |
| `/ebook` | → `/ebook/` → `/ebook/marketing/` | → `/marketing/` | ❌ NG |
| `/ebook/marketing` | → `/ebook/marketing/` | → `/marketing/` | ❌ NG |

### 原因
1. **ALBリスナールール**: ワイルドカードパス（`/contact/*`）がスラッシュ付きのみにマッチ
2. スラッシュなしのURLがデフォルトルールで `/marketing/` にリダイレクト
3. **nginx**: 正規化ルールが未設定

---

## 解決方法

### ステップ1: ALBリスナールールの修正

各パスルールに、スラッシュなしのパターンを追加：

#### 修正内容

| ルール名 | 既存のパスパターン | 追加するパスパターン |
|---------|------------------|-------------------|
| contact-route | `/contact/*` | `/contact` |
| entry-route | `/entry/*` | `/entry` |
| ebook-route | `/ebook/marketing/*` | `/ebook/marketing`, `/ebook` |
| marketing-route | `/marketing/*` | `/marketing` |
| ai-route | `/ai/*` | `/ai` |

**条件設定方法（例: contact-route）:**
```
条件タイプ: パス
演算子: is
値（OR条件で複数指定）:
  - /contact/*
  - /contact
```

**アクション:**
- ターゲットグループに転送（リダイレクトなし）

---

### ステップ2: nginx設定の修正

#### 変更ファイル
- `/etc/nginx/conf.d/10-nxp-dev.conf`
- リポジトリ: `config/nginx/10-nxp-dev.conf`

#### 追加内容

**56行目の前に以下を追加:**

```nginx
# ====================================
# Trailing slash normalization
# ====================================
# スラッシュなしのURLをスラッシュ付きに正規化（301リダイレクト）

location = /marketing {
    return 301 /marketing/;
}

location = /contact {
    return 301 /contact/;
}

location = /entry {
    return 301 /entry/;
}

location = /ai {
    return 301 /ai/;
}

location = /ebook {
    return 301 /ebook/;
}

location = /ebook/marketing {
    return 301 /ebook/marketing/;
}
```

---

## デプロイ手順

### 1. ALBリスナールール修正
1. AWSコンソール → EC2 → ロードバランサー
2. 該当のALBを選択 → リスナータブ → HTTPS:443 → ルールの表示/編集
3. 各ルールを編集して、スラッシュなしのパスパターンを追加
4. 保存

### 2. nginx設定ファイルの更新
```bash
# サーバーにログイン
ssh ec2-user@<server-ip>

# 設定ファイルをバックアップ
sudo cp /etc/nginx/conf.d/10-nxp-dev.conf /etc/nginx/conf.d/10-nxp-dev.conf.backup

# 新しい設定ファイルをアップロード（scpやvimで編集）
# リポジトリの config/nginx/10-nxp-dev.conf を使用

# 設定ファイルの構文チェック
sudo nginx -t

# 問題なければnginxをリロード
sudo systemctl reload nginx
```

### 3. 動作確認
```bash
# Basic認証付きで確認
curl -I -u admin:password https://dev.nxp.nyle.co.jp/contact
# → HTTP/2 301, Location: https://dev.nxp.nyle.co.jp/contact/

curl -I -u admin:password https://dev.nxp.nyle.co.jp/entry
# → HTTP/2 301, Location: https://dev.nxp.nyle.co.jp/entry/

curl -I -u admin:password https://dev.nxp.nyle.co.jp/ebook
# → HTTP/2 301, Location: https://dev.nxp.nyle.co.jp/ebook/

curl -I -u admin:password https://dev.nxp.nyle.co.jp/ebook/marketing
# → HTTP/2 301, Location: https://dev.nxp.nyle.co.jp/ebook/marketing/
```

---

## 期待される動作

| URL | リダイレクト1 | リダイレクト2 | 最終結果 |
|-----|-------------|-------------|---------|
| `/marketing` | → `/marketing/` | - | 200 OK |
| `/contact` | → `/contact/` | - | 200 OK |
| `/entry` | → `/entry/` | - | 200 OK |
| `/ebook` | → `/ebook/` | → `/ebook/marketing/` | 200 OK |
| `/ebook/marketing` | → `/ebook/marketing/` | - | 200 OK |
| `/ai` | → `/ai/` | - | 200 OK |

---

## メリット

### SEO効果
- URL正規化により、検索エンジンが1つの正規URLとして認識
- 重複コンテンツペナルティの回避
- リンクジュースの集約

### ユーザー体験
- URLが統一され、ブックマークやシェア時に一貫性が保たれる
- ブラウザの履歴管理が改善

### アナリティクス
- Google AnalyticsやAdobe Analyticsで同じページへのアクセスが統一される
- データの正確性が向上

### ベストプラクティス準拠
- RFC 3986のURI正規化に準拠
- nginxの推奨設定に従う

---

## 本番環境への適用

本番環境（nxp.nyle.co.jp）にも同様の設定を適用する必要があります。

### チェックリスト
- [ ] dev環境で動作確認完了
- [ ] 本番ALBリスナールールの修正
- [ ] 本番nginxコンフィグの更新
- [ ] 本番環境での動作確認

---

## 参考情報

### nginxドキュメント
- [nginx location directive](http://nginx.org/en/docs/http/ngx_http_core_module.html#location)
- [nginx return directive](http://nginx.org/en/docs/http/ngx_http_rewrite_module.html#return)

### SEOベストプラクティス
- [Google: URL構造のベストプラクティス](https://developers.google.com/search/docs/crawling-indexing/url-structure)
- [RFC 3986: URI正規化](https://datatracker.ietf.org/doc/html/rfc3986#section-6)

---

## トラブルシューティング

### 301リダイレクトが動作しない
- nginxの設定構文エラーを確認: `sudo nginx -t`
- nginxを再起動: `sudo systemctl restart nginx`
- ALBリスナールールの優先度を確認

### 無限リダイレクトループ
- ALBとnginxの両方でリダイレクトしていないか確認
- nginxの `location =` が正確にマッチしているか確認

### 404エラー
- ドキュメントルートのパスを確認
- ファイルの存在を確認: `ls -la /var/www/dev.nxp.nyle.co.jp/`

---

**作業時間:** 約1時間（ALB修正 + nginx更新 + 動作確認）
**ダウンタイム:** なし（設定変更のみ）
