# CI/CD構成ガイド（GitHub Actions）

## 概要

本リポジトリのデプロイはGitHub Actionsを使用し、S3アーティファクト + SSM SendCommand方式でEC2へ配信します。

- **認証**: OIDC（長期アクセスキー不要）
- **ダウンタイム**: なし（`aws s3 sync` による差分同期）
- **対象**: SPAの静的ファイル（ビルドステップなし）

---

## アーキテクチャ

```
GitHub Push
    │
    ▼
GitHub Actions Runner
    ├─ OIDC認証 → AWS IAMロール（一時認証情報）
    ├─ aws s3 sync → S3バケット（nyle-nxp-lp-deploy/{env}/）
    └─ aws ssm send-command → EC2インスタンス
                                  └─ aws s3 sync → /var/www/nyle-nxp-lp/
                                  └─ chmod/chown
```

---

## ブランチとデプロイ環境の対応

| ブランチ | 環境 | URL | 承認 |
|---------|------|-----|------|
| `develop` | dev | `https://dev.nxp.nyle.co.jp` | 不要（自動） |
| `main` | prd | `https://nxp.nyle.co.jp` | 必要（Required reviewers） |

---

## AWSリソース構成

### IAMロール（GitHub Actions用）

| ロール名 | 用途 | 信頼元 |
|---------|------|--------|
| `github-actions-nxp-lp-dev` | dev環境デプロイ | `repo:volareinc/nyle-nxp-lp:environment:dev` |
| `github-actions-nxp-lp-prd` | prd環境デプロイ | `repo:volareinc/nyle-nxp-lp:environment:prd` |

**許可アクション（両ロール共通）:**
- `s3:PutObject`, `s3:DeleteObject`, `s3:GetObject`, `s3:ListBucket` → S3バケット
- `ssm:SendCommand` → AWS-RunShellScriptドキュメント + 対象EC2インスタンス
- `ssm:GetCommandInvocation` → `*`

### IAMロール（EC2用）

| ロール名 | アタッチ先 |
|---------|-----------|
| `nxp-lp-ec2-role` | dev EC2 / prd EC2 両インスタンス |

**付与ポリシー:**
- `AmazonSSMManagedInstanceCore`（AWS管理ポリシー）
- S3バケット `nyle-nxp-lp-deploy` への `s3:GetObject`, `s3:ListBucket`

### S3バケット

| バケット名 | 用途 |
|-----------|------|
| `nyle-nxp-lp-deploy` | デプロイアーティファクト |

```
nyle-nxp-lp-deploy/
├── dev/    ← develop ブランチの成果物
└── prd/    ← main ブランチの成果物
```

パブリックアクセスは全ブロック。

### EC2インスタンス

| 環境 | インスタンス名 | インスタンスID | ドキュメントルート |
|------|-------------|--------------|----------------|
| dev | nxp-lp-dev | i-0195408171d28ba05 | `/var/www/nyle-nxp-lp/` |
| prd | nxp-lp-prd | i-03bd4d530f4d6a31b | `/var/www/nyle-nxp-lp/` |

---

## GitHub設定

### Environments

| Environment | 設定 |
|-------------|------|
| `dev` | Variables: `AWS_DEPLOY_ROLE_ARN` = `arn:aws:iam::420184924451:role/github-actions-nxp-lp-dev` |
| `prd` | Variables: `AWS_DEPLOY_ROLE_ARN` = `arn:aws:iam::420184924451:role/github-actions-nxp-lp-prd`<br>Protection rules: Required reviewers に承認者を設定 |

---

## ワークフローファイル

```
.github/
├── workflows/
│   ├── deploy-dev.yml   # develop → dev環境
│   └── deploy-prd.yml   # main → prd環境（承認ゲートあり）
└── iam/
    ├── trust-policy-dev.json        # IAM OIDC信頼ポリシー（dev）
    ├── trust-policy-prd.json        # IAM OIDC信頼ポリシー（prd）
    ├── permission-policy-dev.json   # IAM許可ポリシー（dev）
    ├── permission-policy-prd.json   # IAM許可ポリシー（prd）
    ├── ec2-instance-policy.json     # EC2インスタンスロール用ポリシー
    └── setup-aws.sh                 # AWSリソース一括作成スクリプト
```

---

## デプロイ手順

### 通常のデプロイフロー

```
feature/xxx ブランチで開発
    │
    └─ develop へPRマージ
            │
            └─ GitHub Actionsが自動実行 → dev環境に反映
                    │
                    └─ dev環境で動作確認
                            │
                            └─ main へPRマージ
                                    │
                                    └─ Required reviewersが承認
                                            │
                                            └─ prd環境に反映
```

### 緊急時（本番直接修正）

mainブランチへのPR + Required reviewers承認 → 自動デプロイ。
hotfixブランチを切ってmainへ直接PRする。

---

## トラブルシューティング

### OIDC認証エラー

```
Not authorized to perform sts:AssumeRoleWithWebIdentity
```

**確認事項:**
- IAMロールの信頼ポリシーの `sub` がリポジトリ名と一致しているか
  - 正: `repo:volareinc/nyle-nxp-lp:environment:dev`
- GitHub Environmentsの名前が一致しているか（大文字小文字も含む）

### SSM権限エラー

```
not authorized to perform: ssm:GetCommandInvocation
```

**確認事項:**
- IAMロールの許可ポリシーに `ssm:GetCommandInvocation` が `Resource: "*"` で許可されているか
- `.github/iam/permission-policy-dev.json` の内容とAWSコンソールのインラインポリシーが一致しているか

### SSM SendCommandがタイムアウト

**確認事項:**
- EC2インスタンスに `nxp-lp-ec2-role` がアタッチされているか
- SSMエージェントが起動しているか: `sudo systemctl status amazon-ssm-agent`
- EC2がSSMエンドポイントに到達できるか（VPCエンドポイントまたはNAT Gateway）

---

## 将来の拡張（ASG + CodeDeploy対応）

現在はEC2スタンドアロン構成。スケールアウト時の移行案：

1. ASGを構成してEC2を複数台に
2. CodeDeployのデプロイグループをASGに紐づけ
3. GitHub Actionsのデプロイステップを `aws deploy create-deployment` に変更
4. CodeDeployのライフサイクルフックでALBターゲットグループの切り離し/再登録を制御

現時点ではCodeDeployはターゲットグループからのインスタンス切り離しによるダウンタイムが発生するため未導入。
