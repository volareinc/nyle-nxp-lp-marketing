# リポジトリ統合作業記録

**日付**: 2026年3月19日
**作業者**: yoshiyuki_km
**PR**: [#14](https://github.com/volareinc/nyle-nxp-lp-marketing/pull/14)

## 概要

`nyle-nxp-lp` リポジトリを `nyle-nxp-lp-marketing` リポジトリの `ai/` ディレクトリに統合する作業を実施。これはリポジトリ統合戦略の第一ステップ。

## 背景と目的

### 課題
- `nyle-nxp-lp` と `nyle-nxp-lp-marketing` の2つのリポジトリが分離して存在
- 管理コストの増加と構造の複雑化
- ランディングページ全体を一元管理したい

### 目標
- **最終目標**: `nyle-nxp-lp` という名前で統一されたランディングページリポジトリを構築
- nyle-nxp-lpのコンテンツを `ai/` ディレクトリに配置
- 履歴はリセット（シンプルで分かりやすい構造を優先）

## 統合戦略の選択

### 検討したオプション

| オプション | 説明 | メリット | デメリット |
|-----------|------|---------|-----------|
| 1. 新リポジトリ作成 | 完全に新規作成 | クリーンな履歴 | 全履歴喪失、URL変更、移行コスト大 |
| 2. git subtree統合 | 履歴を保持して統合 | 両方の履歴保持 | ヒストリが複雑化 |
| **3. ファイルコピー** ✅ | シンプルにコピー | シンプル、ヒストリが汚れない | 統合元の履歴喪失 |
| 4. 逆方向統合 | nyle-nxp-lpをベースに | nyle-nxp-lpの履歴保持 | 要件と逆、URL変更 |

### 選択した戦略

**オプション3（ファイルコピー） + リネーム戦略**

理由：
- ✅ 最もシンプルで分かりやすい
- ✅ nyle-nxp-lp-marketingのヒストリを汚さない
- ✅ 要件（ai/配下に配置）を満たす
- ✅ 後からリポジトリ名を変更可能

## 実施内容（ステップ1）

### 1. ブランチ作成

```bash
git checkout main
git pull origin main
git checkout -b feature/merge-nyle-nxp-lp-to-ai-directory
```

### 2. ファイルコピー

```bash
mkdir -p ai
rsync -av --exclude='.git' --exclude='.DS_Store' ../nyle-nxp-lp/ ./ai/
```

**コピー結果**:
- 78ファイル
- 約15MB
- .gitディレクトリは除外（履歴なし）

### 3. コミット＆プッシュ

```bash
git add ai/
git commit -m "feat: nyle-nxp-lpリポジトリをai/ディレクトリに統合"
git push -u origin feature/merge-nyle-nxp-lp-to-ai-directory
```

### 4. PR作成

- **PR番号**: #14
- **タイトル**: feat: nyle-nxp-lpリポジトリをai/ディレクトリに統合
- **ベースブランチ**: main

### 5. ドキュメント更新

- `README.md` のディレクトリ構造に `ai/` を追加
- 本ドキュメント（作業記録）を作成

## 統合後のディレクトリ構造

```
nyle-nxp-lp-marketing/
├── ai/                           # 統合されたnyle-nxp-lpコンテンツ
│   ├── contact/                 # AI問い合わせページ
│   │   ├── index.html
│   │   └── complete/
│   ├── css/                     # スタイルシート
│   ├── images/                  # 画像アセット
│   ├── img/                     # 画像アセット
│   ├── js/                      # JavaScript
│   ├── index.html              # AIランディングページ
│   ├── .gitignore
│   └── README_ALPHA.md
├── assets/                       # 既存の共通アセット
├── marketing/                    # 既存のマーケティングLP
├── contact/                      # 既存の問い合わせ
└── ...                          # その他既存ディレクトリ
```

## 今後の予定（ステップ2〜4）

### ステップ2: 元のnyle-nxp-lpをリネーム＆アーカイブ

**実施内容**:
1. GitHubで https://github.com/volareinc/nyle-nxp-lp にアクセス
2. Settings → General → Repository name を `nyle-nxp-lp-legacy` に変更
3. Settings → General → 「Archive this repository」でアーカイブ化（read-only）

**目的**:
- リポジトリ名の衝突を回避
- 万が一の時のために履歴を参照可能な状態で保持

### ステップ3: このリポジトリをリネーム

**実施内容**:
1. GitHubで https://github.com/volareinc/nyle-nxp-lp-marketing にアクセス
2. Settings → General → Repository name を `nyle-nxp-lp` に変更

**効果**:
- ✅ `nyle-nxp-lp` = ランディングページ全体を管理するリポジトリ
- ✅ GitHubが自動リダイレクトを設定（旧URL→新URL）
- ✅ 既存のクローン、issue、PR、外部リンクが一定期間機能

### ステップ4（オプション）: legacy削除

**実施タイミング**: ステップ2〜3完了後、数週間〜1ヶ月後

**実施内容**:
- nyle-nxp-lp-legacyが不要と確認できたら削除

## 技術的詳細

### rsyncオプション

```bash
rsync -av --exclude='.git' --exclude='.DS_Store' ../nyle-nxp-lp/ ./ai/
```

- `-a`: アーカイブモード（パーミッション、タイムスタンプ保持）
- `-v`: 詳細出力
- `--exclude='.git'`: Gitディレクトリを除外（履歴なし）
- `--exclude='.DS_Store'`: macOS固有ファイルを除外

### コミット情報

- **コミットハッシュ**: 8c980d4
- **変更行数**: 32,569行追加
- **ファイル数**: 78ファイル

## 注意事項

### ローカルリポジトリの更新（ステップ3後）

リポジトリ名変更後、チームメンバーはリモートURLを更新する必要があります：

```bash
# 自動リダイレクトで一時的に動作しますが、明示的に更新推奨
git remote set-url origin https://github.com/volareinc/nyle-nxp-lp.git
```

### リダイレクトの注意点

- GitHubの自動リダイレクトは永続的ではない
- 同じ名前で新しいリポジトリが作られるとリダイレクト解除
- 今回は自分たちでコントロールできるため問題なし

## まとめ

### 完了事項
- ✅ nyle-nxp-lpの全ファイルをai/ディレクトリに統合
- ✅ featureブランチでコミット＆プッシュ
- ✅ PR #14を作成（main宛）
- ✅ README.mdのディレクトリ構造を更新
- ✅ 作業記録ドキュメントを作成

### 次のアクション
1. PR #14をレビュー＆マージ
2. 元のnyle-nxp-lpをnyle-nxp-lp-legacyにリネーム＆アーカイブ
3. このリポジトリをnyle-nxp-lpにリネーム
4. チームに周知

### メリット
- 統一されたランディングページリポジトリ
- シンプルで分かりやすい構造
- 管理コストの削減
- `nyle-nxp-lp`という明確な名前

---

**関連リソース**:
- PR: https://github.com/volareinc/nyle-nxp-lp-marketing/pull/14
- 旧リポジトリ: https://github.com/volareinc/nyle-nxp-lp
