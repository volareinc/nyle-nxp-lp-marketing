# 末尾スラッシュ正規化対応レポート（本番環境）

**日付:** 2026-03-05
**対象環境:** nxp.nyle.co.jp（本番環境）
**ステータス:** 🔄 実装準備完了（デプロイ待ち）

## 前提条件

- ✅ dev環境で動作確認完了
- ✅ dev環境での正規化が正常動作
- ✅ 本番用nginx設定ファイル準備完了

---

## 本番環境の設定

### dev環境との違い

| 項目 | dev環境 | 本番環境 |
|-----|---------|---------|
| ドメイン | dev.nxp.nyle.co.jp | nxp.nyle.co.jp |
| ドキュメントルート | /var/www/dev.nxp.nyle.co.jp | /var/www/nxp.nyle.co.jp |
| Basic認証 | あり | **なし** |
| 設定ファイル | 10-nxp-dev.conf | 10-nxp-prod.conf |

### 正規化ルール（dev環境と同一）

```nginx
# ====================================
# Trailing slash normalization
# ====================================

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

## デプロイ手順（本番環境）

### 事前確認

```bash
# 本番ALBリスナールールが修正されていることを確認
# - /marketing, /contact, /entry, /ai, /ebook, /ebook/marketing
# 各パスに対して、スラッシュなしのパターンが追加されている
```

### ステップ1: 本番サーバーへのログイン

```bash
# 本番EC2サーバーにログイン
ssh ec2-user@<prod-server-ip>

# または踏み台サーバー経由
ssh -J bastion-user@<bastion-ip> ec2-user@<prod-server-ip>
```

### ステップ2: 現在の設定をバックアップ

```bash
# タイムスタンプ付きバックアップ
sudo cp /etc/nginx/conf.d/10-nxp-prod.conf \
       /etc/nginx/conf.d/10-nxp-prod.conf.backup.$(date +%Y%m%d_%H%M%S)

# バックアップの確認
ls -lh /etc/nginx/conf.d/*.backup.*
```

### ステップ3: 新しい設定ファイルのデプロイ

**方法A: ローカルからscpでアップロード**

```bash
# ローカルマシンで実行
scp config/nginx/10-nxp-prod.conf \
    ec2-user@<prod-server-ip>:/tmp/

# サーバー上で移動
ssh ec2-user@<prod-server-ip>
sudo mv /tmp/10-nxp-prod.conf /etc/nginx/conf.d/10-nxp-prod.conf
sudo chown root:root /etc/nginx/conf.d/10-nxp-prod.conf
sudo chmod 644 /etc/nginx/conf.d/10-nxp-prod.conf
```

**方法B: サーバー上で直接編集**

```bash
# サーバー上で実行
sudo vi /etc/nginx/conf.d/10-nxp-prod.conf

# 50行目の後（location = /ebook/ の前）に以下を追加:
# ====================================
# Trailing slash normalization
# ====================================
# ...（正規化ルール全体をコピー）
```

### ステップ4: 設定ファイルの構文チェック

```bash
# 構文チェック（エラーがないことを確認）
sudo nginx -t

# 期待される出力:
# nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
# nginx: configuration file /etc/nginx/nginx.conf test is successful
```

### ステップ5: nginxのリロード（本番反映）

```bash
# nginxをリロード（ダウンタイムなし）
sudo systemctl reload nginx

# ステータス確認
sudo systemctl status nginx
```

---

## 動作確認（本番環境）

### 確認コマンド

```bash
# 本番環境の301リダイレクトを確認
curl -I https://nxp.nyle.co.jp/contact
# → HTTP/2 301, Location: https://nxp.nyle.co.jp/contact/

curl -I https://nxp.nyle.co.jp/entry
# → HTTP/2 301, Location: https://nxp.nyle.co.jp/entry/

curl -I https://nxp.nyle.co.jp/ebook
# → HTTP/2 301, Location: https://nxp.nyle.co.jp/ebook/

curl -I https://nxp.nyle.co.jp/ebook/marketing
# → HTTP/2 301, Location: https://nxp.nyle.co.jp/ebook/marketing/

curl -I https://nxp.nyle.co.jp/marketing
# → HTTP/2 301, Location: https://nxp.nyle.co.jp/marketing/

curl -I https://nxp.nyle.co.jp/ai
# → HTTP/2 301, Location: https://nxp.nyle.co.jp/ai/
```

### ブラウザでの確認

1. **ブラウザのシークレットモード（キャッシュなし）で開く**
   - https://nxp.nyle.co.jp/contact → 自動的に https://nxp.nyle.co.jp/contact/ に遷移
   - https://nxp.nyle.co.jp/entry → 自動的に https://nxp.nyle.co.jp/entry/ に遷移

2. **開発者ツールで確認**
   - Networkタブで301リダイレクトを確認
   - Locationヘッダーが正しいURLを示している

3. **コンテンツが正常に表示される**
   - すべてのページが期待通りに表示される
   - 画像、CSS、JSが正しく読み込まれている

---

## ロールバック手順

万が一問題が発生した場合:

```bash
# バックアップから復元
sudo cp /etc/nginx/conf.d/10-nxp-prod.conf.backup.YYYYMMDD_HHMMSS \
       /etc/nginx/conf.d/10-nxp-prod.conf

# 構文チェック
sudo nginx -t

# リロード
sudo systemctl reload nginx

# 動作確認
curl -I https://nxp.nyle.co.jp/contact
```

---

## チェックリスト

### デプロイ前
- [ ] dev環境で動作確認完了
- [ ] 本番ALBリスナールールの修正完了
- [ ] デプロイ予定日時を関係者に通知
- [ ] ロールバック手順を確認

### デプロイ時
- [ ] 本番サーバーにログイン成功
- [ ] 現在の設定をバックアップ
- [ ] 新しい設定ファイルをデプロイ
- [ ] `nginx -t` で構文チェック → OK
- [ ] `systemctl reload nginx` でリロード成功

### デプロイ後
- [ ] curl で301リダイレクト確認（6パス）
- [ ] ブラウザ（シークレットモード）で動作確認
- [ ] すべてのページが正常に表示される
- [ ] 開発者ツールでエラーがない
- [ ] Google Analytics/Adobe Analyticsでアクセス確認
- [ ] 関係者に完了を報告

---

## 監視・確認事項

### デプロイ後1時間
- アクセスログでエラーがないか確認
- アナリティクスで異常なトラフィック変動がないか
- ユーザーからの問い合わせがないか

### デプロイ後24時間
- Google Search Consoleでクロールエラーがないか
- アナリティクスでURL正規化が機能しているか
- コンバージョン率に変化がないか

---

## 期待される効果（本番環境）

### SEO改善
- ✅ URL正規化による検索順位の安定化
- ✅ 重複コンテンツペナルティの回避
- ✅ クロール効率の向上

### アナリティクス精度向上
- ✅ 同一ページへのアクセスが統一される
- ✅ コンバージョン計測の精度向上
- ✅ ユーザー行動分析の正確性向上

### ユーザー体験向上
- ✅ URLの一貫性
- ✅ ソーシャルシェア時のURL統一
- ✅ ブックマークの一貫性

---

## 本番ALBリスナールール設定

### 修正が必要なルール

dev環境と同様に、以下のパスパターンを追加:

| ルール名 | 既存パターン | 追加パターン |
|---------|------------|------------|
| prod-marketing-route | `/marketing/*` | `/marketing` |
| prod-contact-route | `/contact/*` | `/contact` |
| prod-entry-route | `/entry/*` | `/entry` |
| prod-ebook-route | `/ebook/marketing/*` | `/ebook/marketing`, `/ebook` |
| prod-ai-route | `/ai/*` | `/ai` |

### 設定手順

1. AWSコンソール → EC2 → ロードバランサー
2. 本番ALBを選択
3. リスナータブ → HTTPS:443 → ルールの表示/編集
4. 各ルールを編集してパスパターンを追加
5. 保存

---

## トラブルシューティング（本番環境）

### 問題: 301リダイレクトが動作しない

**確認:**
```bash
# nginxのエラーログを確認
sudo tail -f /var/log/nginx/nxp.nyle.co.jp_error.log

# ALBのターゲットヘルスを確認
# AWSコンソール → EC2 → ターゲットグループ
```

**対処:**
1. nginx設定の構文エラーを確認
2. ALBリスナールールの優先度を確認
3. 必要に応じてロールバック

### 問題: ページが表示されない（502/503エラー）

**確認:**
```bash
# nginxのステータス確認
sudo systemctl status nginx

# アクセスログを確認
sudo tail -f /var/log/nginx/nxp.nyle.co.jp_access.log
```

**対処:**
1. 即座にロールバック
2. エラーログを詳細に確認
3. 問題を修正してから再デプロイ

---

## 参考情報

### 関連ドキュメント
- dev環境レポート: `docs/2026-03-05_trailing-slash-normalization.md`
- nginx設定ファイル: `config/nginx/10-nxp-prod.conf`

### 連絡先
- インフラ担当: [担当者名]
- 緊急連絡先: [電話番号]

---

**推定作業時間:** 30分（デプロイ + 動作確認）
**推奨デプロイ時間:** 平日の業務時間内（ロールバック対応が可能な時間帯）
**ダウンタイム:** なし（nginxリロードのみ）
