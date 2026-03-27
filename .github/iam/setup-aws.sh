#!/bin/bash
# AWS リソースセットアップスクリプト
# 実行前に: aws configure で適切なプロファイルを設定してください
# 実行例: AWS_PROFILE=your-profile bash .github/iam/setup-aws.sh

set -euo pipefail

ACCOUNT_ID="420184924451"
REGION="ap-northeast-1"
S3_BUCKET="nyle-nxp-lp-deploy"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Step 1: OIDC Identity Provider の登録 ==="
echo "（AWSアカウントに既に登録済みの場合はスキップ）"

EXISTING=$(aws iam list-open-id-connect-providers \
  --query "OpenIDConnectProviderList[?ends_with(Arn, 'token.actions.githubusercontent.com')]" \
  --output text)

if [ -z "$EXISTING" ]; then
  # Githubの thumbprint 取得
  THUMBPRINT=$(echo | openssl s_client -servername token.actions.githubusercontent.com \
    -connect token.actions.githubusercontent.com:443 2>/dev/null \
    | openssl x509 -fingerprint -noout -sha1 \
    | sed 's/.*=//' | tr -d ':' | tr '[:upper:]' '[:lower:]')

  aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list "$THUMBPRINT"
  echo "OIDCプロバイダーを登録しました"
else
  echo "OIDCプロバイダーは既に登録済みです（スキップ）"
fi

echo ""
echo "=== Step 2: S3 バケット作成 ==="

if aws s3api head-bucket --bucket "$S3_BUCKET" 2>/dev/null; then
  echo "S3バケット $S3_BUCKET は既に存在します（スキップ）"
else
  aws s3api create-bucket \
    --bucket "$S3_BUCKET" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION"

  # パブリックアクセスブロック（アーティファクトバケットなので全ブロック）
  aws s3api put-public-access-block \
    --bucket "$S3_BUCKET" \
    --public-access-block-configuration \
      "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

  echo "S3バケット $S3_BUCKET を作成しました"
fi

echo ""
echo "=== Step 3: IAM ロール作成（dev）==="

ROLE_NAME_DEV="github-actions-nxp-lp-dev"

if aws iam get-role --role-name "$ROLE_NAME_DEV" 2>/dev/null; then
  echo "IAMロール $ROLE_NAME_DEV は既に存在します（スキップ）"
else
  ROLE_ARN_DEV=$(aws iam create-role \
    --role-name "$ROLE_NAME_DEV" \
    --assume-role-policy-document "file://${SCRIPT_DIR}/trust-policy-dev.json" \
    --query "Role.Arn" \
    --output text)

  aws iam put-role-policy \
    --role-name "$ROLE_NAME_DEV" \
    --policy-name "nxp-lp-deploy-dev" \
    --policy-document "file://${SCRIPT_DIR}/permission-policy-dev.json"

  echo "IAMロール作成完了: $ROLE_ARN_DEV"
fi

echo ""
echo "=== Step 4: IAM ロール作成（prd）==="

ROLE_NAME_PRD="github-actions-nxp-lp-prd"

if aws iam get-role --role-name "$ROLE_NAME_PRD" 2>/dev/null; then
  echo "IAMロール $ROLE_NAME_PRD は既に存在します（スキップ）"
else
  ROLE_ARN_PRD=$(aws iam create-role \
    --role-name "$ROLE_NAME_PRD" \
    --assume-role-policy-document "file://${SCRIPT_DIR}/trust-policy-prd.json" \
    --query "Role.Arn" \
    --output text)

  aws iam put-role-policy \
    --role-name "$ROLE_NAME_PRD" \
    --policy-name "nxp-lp-deploy-prd" \
    --policy-document "file://${SCRIPT_DIR}/permission-policy-prd.json"

  echo "IAMロール作成完了: $ROLE_ARN_PRD"
fi

echo ""
echo "=== 完了 ==="
echo ""
echo "次のステップ: GitHub Environments に以下を設定してください"
echo ""
echo "【dev environment】"
aws iam get-role --role-name "$ROLE_NAME_DEV" --query "Role.Arn" --output text 2>/dev/null \
  && echo "  Variables > AWS_DEPLOY_ROLE_ARN = $(aws iam get-role --role-name "$ROLE_NAME_DEV" --query "Role.Arn" --output text)"
echo ""
echo "【prd environment】"
aws iam get-role --role-name "$ROLE_NAME_PRD" --query "Role.Arn" --output text 2>/dev/null \
  && echo "  Variables > AWS_DEPLOY_ROLE_ARN = $(aws iam get-role --role-name "$ROLE_NAME_PRD" --query "Role.Arn" --output text)"
echo "  Required reviewers に承認者を設定してください"
