# nyle-nxp-lp-marketing 移行完了レポート

## 作業日時
2026年3月3日

## 概要
旧リポジトリ（nxp-seohacks）から新リポジトリ（nyle-nxp-lp-marketing）への移行作業が完了しました。

## 実施内容

### 1. ディレクトリ構造の再編成
- 共通アセットを `assets/` 配下に統合
- ページごとのディレクトリを新規作成
- パスの正規化（`form.html` → `form/index.html`）

### 2. ドメイン・URL変更
- **旧ドメイン**: `https://x.seohacks.net/`
- **新ドメイン**: `https://nxp.nyle.co.jp/`

### 3. パス変更
| 旧パス | 新パス |
|--------|--------|
| `/` | `/marketing/` |
| `/nxp-contact/` | `/contact/` |
| `/nxp-service/` | `/ebook/marketing/` |
| `/entry/form.html` | `/entry/form/` |

### 4. アセット統合
- `img/` → `assets/img/` (47ファイル)
- `css/` → `assets/css/` (2ファイル)
- `js/` → `assets/js/` (1ファイル)

### 5. HTMLファイル変換
- **対象**: 13ファイル
- **変更内容**:
  - OGPメタタグのドメイン変更
  - 相対パスの変更
  - 内部リンクのパス変更

### 6. リダイレクト実装
- `/index.html`: ルート → `/marketing/`
- `/ebook/index.html`: `/ebook/` → `/ebook/marketing/`

## 変更統計

```
169 files changed, 7567 insertions(+)
```

### ファイル内訳
- HTML: 13ファイル
- 画像: 124ファイル
- CSS: 2ファイル
- JS: 1ファイル
- 設定: 6ファイル
- その他: 23ファイル

## 変更詳細

### marketing/index.html（旧 index.html）
- ドメイン: `x.seohacks.net` → `nxp.nyle.co.jp/marketing/`
- パス: `img/` → `../assets/img/`
- パス: `css/` → `../assets/css/`
- パス: `js/` → `../assets/js/`
- リンク: `./nxp-contact/` → `../contact/`
- リンク: `./nxp-service/` → `../ebook/marketing/`

### contact/index.html（旧 nxp-contact/index.html）
- ドメイン: `x.seohacks.net/nxp-contact/` → `nxp.nyle.co.jp/contact/`
- パス: `../img/` → `../assets/img/`
- パス: `../css/` → `../assets/css/`
- リンク: `../` → `../marketing/`

### ebook/marketing/index.html（旧 nxp-service/index.html）
- ドメイン: `x.seohacks.net/nxp-service/` → `nxp.nyle.co.jp/ebook/marketing/`
- パス: `../img/` → `../../assets/img/`
- パス: `../css/` → `../../assets/css/`
- リンク: `../` → `../../marketing/`

### entry/form/index.html（旧 entry/form.html）
- ドメイン: `x.seohacks.net/entry/form.html` → `nxp.nyle.co.jp/entry/form`
- パス: `../img/` → `../../assets/img/`
- パス: `../css/` → `../../assets/css/`
- パス正規化: `form.html` → `form/index.html`

## 未実施項目

### 1. 共通HTMLパーツの配置
- 旧リポジトリの `inc/` ディレクトリ（フッターなど）
- 新リポジトリの `includes/` ディレクトリは未作成
- 各HTMLで `fetch('../includes/footer.html')` の参照あり
- **対応方法**:
  - Option A: `includes/` ディレクトリを作成して共通パーツを配置
  - Option B: 各HTMLに直接フッターを埋め込む

### 2. nxp-is-contact/ の扱い
- 旧リポジトリに存在するが、移行計画に含まれず
- **要確認**: このページは必要か？

## 検証項目（ローカル環境）

### 基本動作
- [ ] `/` → `/marketing/` へのリダイレクト
- [ ] `/ebook/` → `/ebook/marketing/` へのリダイレクト

### 全ページの表示確認
- [ ] `/marketing/` - トップページ
- [ ] `/contact/` - 問い合わせフォーム
- [ ] `/contact/complete/` - 完了ページ
- [ ] `/ebook/marketing/` - 資料DL
- [ ] `/ebook/complete/` - 完了ページ
- [ ] `/entry/` - 人材募集
- [ ] `/entry/form/` - フォーム
- [ ] `/entry/complete/` - 完了ページ

### アセット読み込み
- [ ] 画像の表示確認（全ページ）
- [ ] CSSの適用確認
- [ ] JavaScriptの動作確認
- [ ] ファビコン表示確認

### リンク動作
- [ ] ヘッダーナビゲーション
- [ ] フッターリンク
- [ ] CTA ボタン
- [ ] 内部リンク

## 次のアクション

### 1. ローカル動作確認
```bash
cd /Users/yoshiyuki_km/Repo_DXM/nyle-nxp-lp-marketing
python3 -m http.server 8000
```

### 2. 共通パーツ対応
- `includes/` ディレクトリ作成
- フッターHTMLの配置

### 3. GitHubリポジトリ作成
```bash
git remote add origin https://github.com/volareinc/nyle-nxp-lp-marketing.git
git branch -M main
git push -u origin main
```

### 4. 開発環境デプロイ
- S3 + CloudFront または EC2 + nginx
- DNS設定（開発環境サブドメイン）
- 全ページの動作確認

### 5. 本番環境デプロイ
- ACM証明書作成
- 本番DNS設定
- 旧ドメインからの301リダイレクト設定
- Google Search Console アドレス変更申請

## リスク・注意事項

1. **OGP画像の確認**
   - 絶対パス: `https://nxp.nyle.co.jp/assets/img/ogp.webp`
   - Facebook Sharing Debugger で確認必須

2. **HubSpotフォームの動作確認**
   - contact/index.html
   - ebook/marketing/index.html
   - entry/form/index.html

3. **Google Tag Manager**
   - GTM-K7CPD87F の動作確認

4. **旧ドメイン対応**
   - 最低1ヶ月間は旧サイト維持
   - アクセスログ監視

## 作業者
- Claude Sonnet 4.5 (AI)

## 承認
- [ ] ローカル動作確認完了
- [ ] レビュー完了
- [ ] 開発環境デプロイ承認
- [ ] 本番環境デプロイ承認
