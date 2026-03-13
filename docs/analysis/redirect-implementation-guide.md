# URL正規化・リダイレクト設定 実装ガイド

**作成日**: 2026-03-13
**対象環境**: nxp.nyle.co.jp (本番) / dev.nxp.nyle.co.jp (開発)
**関連ドキュメント**: `url-normalization-redirect-analysis.md`

---

## 概要

本ドキュメントは、分析レポート（`url-normalization-redirect-analysis.md`）で特定された問題を解決するための具体的な実装手順を提供します。

---

## 1. Phase 1: 緊急対応（二重リダイレクト解消）

### 1.1 目的

**HTTPS→HTTP→HTTPS二重リダイレクトチェーンを解消**

現状:
```
ユーザー → HTTPS /marketing
  ↓
ALB → nginx (HTTP /marketing)
  ↓
nginx → 301 http://nxp.nyle.co.jp/marketing/
  ↓
ALB → 301 https://nxp.nyle.co.jp/marketing/
  ↓
ALB → nginx (HTTP /marketing/)
  ↓
200 OK
```

改善後:
```
ユーザー → HTTPS /marketing
  ↓
ALB → 301 https://nxp.nyle.co.jp/marketing/
  ↓
ALB → nginx (HTTP /marketing/)
  ↓
200 OK
```

### 1.2 実装手順

#### Step 1: nginxからTrailing Slash正規化を削除

**対象ファイル**:
- `config/nginx/10-nxp-prod.conf`
- `config/nginx/10-nxp-dev.conf`

**削除する箇所**（両ファイル共通）:

```nginx
# ====================================
# Trailing slash normalization
# ====================================
# 以下の8つのlocationブロックを削除

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

location = /ai/contact {
    return 301 /ai/contact/;
}

location = /ebook {
    return 301 /ebook/;
}

location = /ebook/marketing {
    return 301 /ebook/marketing/;
}

location = /ebook/complete {
    return 301 /ebook/complete/;
}
```

**削除後の `10-nxp-prod.conf` 該当部分**:

```nginx
# ALB health check
location = /healthz {
    add_header Content-Type text/plain;
    return 200 "OK\n";
}

# ====================================
# Path redirects
# ====================================

# /ebook/ → /ebook/marketing/
location = /ebook/ {
    return 301 /ebook/marketing/;
}

# /ai/contact/ → /ai/ (完了ページは除外)
location = /ai/contact/ {
    return 301 /ai/;
}

# 以下、index.htmlのキャッシュ設定...
```

**変更箇所**: 本番・開発共にL54-L89を削除

#### Step 2: ALBにTrailing Slash正規化ルールを追加

**AWS Console での設定手順**:

1. **ALBリスナーを開く**
   - AWS Console → EC2 → Load Balancers
   - `dgm-media--ALB` を選択
   - Listeners タブ → `HTTPS:443` を選択
   - "Manage rules" をクリック

2. **新しいルールを追加**（Priority 20-27）

   **Rule 1: /marketing の正規化**
   - Priority: 20
   - Conditions:
     - Path: `/marketing` (完全一致)
   - Actions:
     - Type: Redirect
     - Protocol: HTTPS
     - Port: 443
     - Path: `/marketing/`
     - Query string: `#{query}`
     - Status code: 301

   **Rule 2: /contact の正規化**
   - Priority: 21
   - Conditions: Path = `/contact`
   - Actions: 301 Redirect → `/contact/`

   **Rule 3: /entry の正規化**
   - Priority: 22
   - Conditions: Path = `/entry`
   - Actions: 301 Redirect → `/entry/`

   **Rule 4: /ebook の正規化**
   - Priority: 23
   - Conditions: Path = `/ebook`
   - Actions: 301 Redirect → `/ebook/`

   **Rule 5: /ebook/marketing の正規化**
   - Priority: 24
   - Conditions: Path = `/ebook/marketing`
   - Actions: 301 Redirect → `/ebook/marketing/`

   **Rule 6: /ebook/complete の正規化**
   - Priority: 25
   - Conditions: Path = `/ebook/complete`
   - Actions: 301 Redirect → `/ebook/complete/`

   **Rule 7: /ai の正規化**
   - Priority: 26
   - Conditions: Path = `/ai`
   - Actions: 301 Redirect → `/ai/`

   **Rule 8: /ai/contact の正規化**
   - Priority: 27
   - Conditions: Path = `/ai/contact`
   - Actions: 301 Redirect → `/ai/contact/`

**Terraform実装例**:

```hcl
# Trailing slash正規化ルール（/marketing）
resource "aws_lb_listener_rule" "redirect_marketing_trailing_slash" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 20

  condition {
    path_pattern {
      values = ["/marketing"]
    }
  }

  action {
    type = "redirect"
    redirect {
      protocol    = "HTTPS"
      port        = "443"
      path        = "/marketing/"
      query       = "#{query}"
      status_code = "HTTP_301"
    }
  }
}

# 他のパスも同様に定義...
```

**開発環境（dev.nxp.nyle.co.jp）にも同様のルールを追加**:
- Priority 101-108（Host条件: `dev.nxp.nyle.co.jp`）

#### Step 3: デプロイと確認

**1. nginx設定のデプロイ**

```bash
# 本番環境
ssh ec2-user@<本番EC2-IP>
sudo cp /path/to/10-nxp-prod.conf /etc/nginx/conf.d/10-nxp-prod.conf
sudo nginx -t  # 設定ファイルの文法チェック
sudo systemctl reload nginx

# 開発環境
ssh ec2-user@<開発EC2-IP>
sudo cp /path/to/10-nxp-dev.conf /etc/nginx/conf.d/10-nxp-dev.conf
sudo nginx -t
sudo systemctl reload nginx
```

**2. ALB設定の確認**

AWS Consoleで各ルールが正しく追加されているか確認:
- Priority順に並んでいるか
- Conditions（Path）が正確か
- Actions（Redirect）のパスが正しいか

**3. 動作確認テスト**

```bash
#!/bin/bash
# test-redirects.sh

echo "=== Trailing Slash正規化テスト ==="

test_redirect() {
    local url=$1
    local expected_location=$2

    echo "Testing: $url"
    result=$(curl -I -s "$url" | grep -E "^HTTP|^location:")
    echo "$result"

    if echo "$result" | grep -q "$expected_location"; then
        echo "✅ PASS"
    else
        echo "❌ FAIL: Expected $expected_location"
    fi
    echo "---"
}

# 本番環境テスト
test_redirect "https://nxp.nyle.co.jp/marketing" "location: https://nxp.nyle.co.jp/marketing/"
test_redirect "https://nxp.nyle.co.jp/contact" "location: https://nxp.nyle.co.jp/contact/"
test_redirect "https://nxp.nyle.co.jp/entry" "location: https://nxp.nyle.co.jp/entry/"
test_redirect "https://nxp.nyle.co.jp/ebook" "location: https://nxp.nyle.co.jp/ebook/"
test_redirect "https://nxp.nyle.co.jp/ai" "location: https://nxp.nyle.co.jp/ai/"

# 開発環境テスト
test_redirect "https://dev.nxp.nyle.co.jp/marketing" "location: https://dev.nxp.nyle.co.jp/marketing/"
```

**期待される結果**:

```
Testing: https://nxp.nyle.co.jp/marketing
HTTP/2 301
location: https://nxp.nyle.co.jp/marketing/
✅ PASS
---
```

**重要**: リダイレクトが**1回のみ**であることを確認してください。

**4. パフォーマンス測定**

```bash
# Before/After比較
curl -w "@curl-timing.txt" -o /dev/null -s https://nxp.nyle.co.jp/marketing

# curl-timing.txt の内容:
#   time_namelookup:  %{time_namelookup}s\n
#   time_connect:  %{time_connect}s\n
#   time_appconnect:  %{time_appconnect}s\n
#   time_pretransfer:  %{time_pretransfer}s\n
#   time_redirect:  %{time_redirect}s\n
#   time_starttransfer:  %{time_starttransfer}s\n
#   time_total:  %{time_total}s\n
#   num_redirects:  %{num_redirects}\n
```

**改善前**: `time_redirect: 0.3-0.5s`, `num_redirects: 2`
**改善後**: `time_redirect: 0.1-0.2s`, `num_redirects: 1`

### 1.3 ロールバック手順

問題が発生した場合:

**1. nginx設定を元に戻す**
```bash
git revert <commit-hash>
# または
git checkout HEAD~1 config/nginx/10-nxp-prod.conf
sudo systemctl reload nginx
```

**2. ALB設定を削除**
- AWS Console → 追加したルール（Priority 20-27）を削除

### 1.4 成功基準

- [ ] `/marketing` アクセス時のリダイレクト回数が1回
- [ ] HTTPステータスコードが301
- [ ] リダイレクト先が `https://nxp.nyle.co.jp/marketing/`（HTTP→HTTPSなし）
- [ ] パフォーマンステストで150ms以上の改善
- [ ] 全URLパターンで正常動作

---

## 2. Phase 2: 設定の整理

### 2.1 目的

**冗長な設定ファイルと重複定義を削除**

### 2.2 実装手順

#### Step 1: nginxから重複リダイレクトを削除

**対象ファイル**: `config/nginx/10-nxp-prod.conf`, `10-nxp-dev.conf`

**削除する箇所**:

```nginx
# ====================================
# Path redirects
# ====================================

# /ebook/ → /ebook/marketing/
location = /ebook/ {
    return 301 /ebook/marketing/;
}

# /ai/contact/ → /ai/ (完了ページは除外)
location = /ai/contact/ {
    return 301 /ai/;
}
```

**理由**: これらのリダイレクトはALBで既に処理されている（Priority 84, 不明）

**注意**: ALBで `/ai/contact/` → `/ai/` のリダイレクトルールが存在しない場合、ALBに追加してからnginxから削除してください。

#### Step 2: 未使用ファイルの削除

```bash
cd /Users/yoshiyuki_km/Repo_DXM/nyle-nxp-lp-marketing

# 未使用設定ファイルを削除
git rm config/nginx/nxp.conf
git rm config/s3-cloudfront/cloudfront-function-redirect.js
git rm -r config/redirect-templates/

# コミット
git commit -m "chore: 未使用のリダイレクト設定ファイルを削除

- config/nginx/nxp.conf: レガシー設定、現在未使用
- config/s3-cloudfront/cloudfront-function-redirect.js: CloudFront未使用のため不要
- config/redirect-templates/: サーバーサイドリダイレクトで対応するため不要

関連: docs/analysis/url-normalization-redirect-analysis.md"
```

#### Step 3: ドキュメント作成

**1. ALBルーティングルール一覧**

ファイル: `docs/infrastructure/alb-routing-rules.md`

```markdown
# ALB Routing Rules - nxp.nyle.co.jp

## 本番環境（nxp.nyle.co.jp）

### HTTP→HTTPSリダイレクト
- Listener: HTTP:80
- Action: Redirect to HTTPS:443

### HTTPSルール（Priority順）

| Priority | Condition | Action | Description |
|---------|-----------|--------|-------------|
| 10 | Path = `/` | 301 → `/marketing/` | ルート正規化 |
| 20-27 | Path = 主要パス（trailing slashなし） | 301 → trailing slash付き | URL正規化 |
| 84 | Path = `/ebook/` | 301 → `/ebook/marketing/` | ebook正規化 |
| 81-89 | Path = 各種パターン | Forward to TG | アプリケーション転送 |
| 90 | Default | 301 → `/marketing/` | フォールバック |

## 開発環境（dev.nxp.nyle.co.jp）

本番と同様の構成（Priority 101-110）
```

**2. nginx設定解説**

ファイル: `docs/infrastructure/nginx-configuration.md`

```markdown
# nginx設定 - nxp.nyle.co.jp

## 設計方針

- **ALB**: プロトコル・URL正規化を処理
- **nginx**: SPAルーティング、キャッシュ、セキュリティヘッダーを処理

## 主要機能

### 1. SPAフォールバック
各LPディレクトリで404時にindex.htmlにフォールバック

### 2. キャッシュ制御
- index.html: no-store（常に最新版を取得）
- Assets: max-age=31536000, immutable（長期キャッシュ）

### 3. セキュリティヘッダー
- X-Content-Type-Options: nosniff
- X-Frame-Options: SAMEORIGIN
- Referrer-Policy: strict-origin-when-cross-origin
```

**3. リダイレクトポリシー**

ファイル: `docs/infrastructure/redirect-policy.md`

```markdown
# リダイレクトポリシー

## 301 vs 302の使い分け

| シナリオ | ステータスコード | 理由 |
|---------|---------------|------|
| URL構造の恒久的変更 | **301** | SEO評価継承 |
| キャンペーン | 302/307 | 一時的 |
| メンテナンス | 503 | サービス停止 |

## リダイレクトチェーンの禁止

最大1回のリダイレクトを厳守。
2回以上のチェーンはSEOとパフォーマンスに悪影響。
```

#### Step 4: 確認とデプロイ

```bash
# 変更をコミット
git add .
git commit -m "docs: インフラ設定ドキュメントを追加"

# プルリクエスト作成
git checkout -b refactor/redirect-optimization
git push origin refactor/redirect-optimization
```

### 2.3 成功基準

- [ ] 未使用ファイルが削除されている
- [ ] ドキュメントが作成されている
- [ ] nginx設定が簡潔になっている
- [ ] 機能的に変化なし（全テストがPASS）

---

## 3. Phase 3: 最適化と改善

### 3.1 ALBルールの最適化

#### 問題1: ポート指定（`:443`）の削除

**現状**:
```
location: https://nxp.nyle.co.jp:443/marketing/
```

**改善後**:
```
location: https://nxp.nyle.co.jp/marketing/
```

**AWS Console での修正**:
1. 各リダイレクトルールを編集
2. Port: `443` → 空白
3. 保存

**Terraform実装**:
```hcl
action {
  type = "redirect"
  redirect {
    protocol    = "HTTPS"
    # port = "443"  # 削除（デフォルトポートのため不要）
    path        = "/marketing/"
    status_code = "HTTP_301"
  }
}
```

#### 問題2: 優先度の整理

**現状**: Priority 81-90, 101-110がバラバラ

**改善後**: 論理的にグルーピング

| Priority範囲 | 用途 |
|------------|------|
| 1-10 | ドメイン正規化（旧ドメイン→新ドメイン） |
| 11-20 | パス正規化（ルート、特殊パス） |
| 21-50 | Trailing slash正規化 |
| 51-80 | アプリケーション固有のリダイレクト |
| 81-100 | 転送ルール（Forward to Target Group） |
| 101+ | デフォルトルール |

### 3.2 Basic認証の見直し

**現状確認**:
```bash
# 本番環境でBasic認証が有効か確認
curl -I https://nxp.nyle.co.jp/marketing/
# → 401 Unauthorized の場合、Basic認証が有効
```

**オプション1: 本番公開時に削除**

```nginx
# config/nginx/10-nxp-prod.conf

# Basic認証を削除
# auth_basic "Restricted";
# auth_basic_user_file /etc/nginx/.htpasswd-dev-nxp;
```

**オプション2: 環境変数で制御**

```nginx
# Basic認証の有効/無効を環境変数で制御
set $auth_basic_enabled "off";

# 環境変数から読み込み（systemd環境変数など）
# export AUTH_BASIC_ENABLED="Restricted"

auth_basic $auth_basic_enabled;
auth_basic_user_file /etc/nginx/.htpasswd-dev-nxp;
```

**オプション3: 開発環境のみ有効**

本番: `10-nxp-prod.conf` から削除
開発: `10-nxp-dev.conf` で保持

### 3.3 IaCの導入

**Terraform実装例**:

```hcl
# terraform/alb-rules.tf

locals {
  trailing_slash_paths = [
    "/marketing",
    "/contact",
    "/entry",
    "/ebook",
    "/ebook/marketing",
    "/ebook/complete",
    "/ai",
    "/ai/contact"
  ]
}

# Trailing slash正規化ルールを動的に生成
resource "aws_lb_listener_rule" "trailing_slash_redirects" {
  count = length(local.trailing_slash_paths)

  listener_arn = aws_lb_listener.https.arn
  priority     = 20 + count.index

  condition {
    path_pattern {
      values = [local.trailing_slash_paths[count.index]]
    }
  }

  action {
    type = "redirect"
    redirect {
      protocol    = "HTTPS"
      path        = "${local.trailing_slash_paths[count.index]}/"
      query       = "#{query}"
      status_code = "HTTP_301"
    }
  }
}

# ルート正規化
resource "aws_lb_listener_rule" "redirect_root" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  condition {
    path_pattern {
      values = ["/"]
    }
  }

  action {
    type = "redirect"
    redirect {
      protocol    = "HTTPS"
      path        = "/marketing/"
      status_code = "HTTP_301"
    }
  }
}

# /ebook/ → /ebook/marketing/
resource "aws_lb_listener_rule" "redirect_ebook" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 11

  condition {
    path_pattern {
      values = ["/ebook/"]
    }
  }

  action {
    type = "redirect"
    redirect {
      protocol    = "HTTPS"
      path        = "/ebook/marketing/"
      status_code = "HTTP_301"
    }
  }
}

# アプリケーション転送ルール
resource "aws_lb_listener_rule" "forward_marketing" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 81

  condition {
    path_pattern {
      values = ["/marketing/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nxp_marketing_prd.arn
  }
}

# 他のパスも同様...
```

**導入ステップ**:
1. 現在のALB設定をTerraformでimport
2. `terraform plan` で差分確認
3. ステージング環境で検証
4. 本番環境にapply

### 3.4 監視とアラート設定

**CloudWatch Metricsで監視**:

1. **リダイレクト回数**
   - Metric: `TargetResponseTime`
   - Alarm: 200ms以上でアラート

2. **4xx/5xxエラー率**
   - Metric: `HTTPCode_Target_4XX_Count`, `HTTPCode_Target_5XX_Count`
   - Alarm: エラー率5%以上でアラート

3. **リクエスト数**
   - Metric: `RequestCount`
   - Alarm: 異常なトラフィック増加でアラート

**ログ分析**:
```bash
# ALBアクセスログからリダイレクトを抽出
aws s3 cp s3://alb-logs-bucket/... - | \
  grep "301\|302" | \
  awk '{print $13, $15}' | \
  sort | uniq -c | sort -nr
```

---

## 4. テスト計画

### 4.1 機能テスト

**テストケース一覧**: `docs/testing/redirect-test-cases.md`

| ID | URL | 期待結果 | 確認事項 |
|----|-----|---------|---------|
| TC-001 | `https://nxp.nyle.co.jp` | 301 → `/marketing/` | 1回リダイレクト |
| TC-002 | `https://nxp.nyle.co.jp/` | 301 → `/marketing/` | 1回リダイレクト |
| TC-003 | `https://nxp.nyle.co.jp/marketing` | 301 → `/marketing/` | 1回リダイレクト、HTTPS維持 |
| TC-004 | `https://nxp.nyle.co.jp/marketing/` | 200 OK | リダイレクトなし |
| TC-005 | `https://nxp.nyle.co.jp/ebook` | 301 → `/ebook/` | Trailing slash追加 |
| TC-006 | `https://nxp.nyle.co.jp/ebook/` | 301 → `/ebook/marketing/` | 1回リダイレクト |
| TC-007 | `https://nxp.nyle.co.jp/ebook/marketing` | 301 → `/ebook/marketing/` | 1回リダイレクト |
| TC-008 | `http://nxp.nyle.co.jp/marketing` | 301 → HTTPS, 301 → `/marketing/` | 2回リダイレクト（許容） |
| TC-009 | `https://nxp.nyle.co.jp/contact` | 301 → `/contact/` | 1回リダイレクト |
| TC-010 | `https://nxp.nyle.co.jp/entry/form/` | 200 OK | SPAフォールバック |
| TC-011 | `https://nxp.nyle.co.jp/assets/img/logo.png` | 200 OK, Cache-Control | 静的ファイル |
| TC-012 | `https://nxp.nyle.co.jp/marketing/index.html` | 200 OK, no-store | index.htmlキャッシュなし |

### 4.2 パフォーマンステスト

**測定ツール**: WebPageTest, Lighthouse, curl

**測定項目**:

1. **TTFB (Time to First Byte)**
   ```bash
   curl -w "TTFB: %{time_starttransfer}s\n" -o /dev/null -s https://nxp.nyle.co.jp/marketing
   ```

2. **Total Load Time**
   ```bash
   curl -w "Total: %{time_total}s\nRedirects: %{num_redirects}\n" -o /dev/null -s -L https://nxp.nyle.co.jp/marketing
   ```

3. **Lighthouse Performance Score**
   ```bash
   lighthouse https://nxp.nyle.co.jp/marketing/ --only-categories=performance --output=json
   ```

**改善目標**:
- TTFB: 150ms以上短縮
- Total Load Time: 200ms以上短縮
- Redirect Count: 1回以下（HTTP→HTTPSを除く）
- Lighthouse Score: 5点以上向上

### 4.3 SEOテスト

1. **Google Search Console**
   - URL検査ツールでリダイレクトチェーンを確認
   - クロールエラーがないか確認

2. **301 vs 302確認**
   ```bash
   curl -I https://nxp.nyle.co.jp/ | grep "HTTP\|Location"
   # HTTP/2 301 であることを確認
   ```

3. **canonical URL確認**
   - HTMLに `<link rel="canonical" href="...">` が正しく設定されているか

### 4.4 自動テストの実装

**GitHub Actions ワークフロー**:

```yaml
# .github/workflows/redirect-test.yml
name: Redirect Tests

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  test-redirects:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Test Production Redirects
        run: |
          bash scripts/test-redirects.sh https://nxp.nyle.co.jp

      - name: Test Development Redirects
        run: |
          bash scripts/test-redirects.sh https://dev.nxp.nyle.co.jp

      - name: Performance Test
        run: |
          bash scripts/performance-test.sh
```

**テストスクリプト**: `scripts/test-redirects.sh`

```bash
#!/bin/bash
set -e

BASE_URL=$1
FAILED=0

test_redirect() {
    local path=$1
    local expected_location=$2
    local expected_status=$3

    echo "Testing: $BASE_URL$path"

    response=$(curl -I -s "$BASE_URL$path")
    status=$(echo "$response" | grep "^HTTP" | head -1 | awk '{print $2}')
    location=$(echo "$response" | grep -i "^location:" | awk '{print $2}' | tr -d '\r')

    if [ "$status" != "$expected_status" ]; then
        echo "❌ FAIL: Expected status $expected_status, got $status"
        FAILED=$((FAILED + 1))
        return 1
    fi

    if [ -n "$expected_location" ] && [ "$location" != "$expected_location" ]; then
        echo "❌ FAIL: Expected location $expected_location, got $location"
        FAILED=$((FAILED + 1))
        return 1
    fi

    echo "✅ PASS"
    return 0
}

# テストケース
test_redirect "/" "https://nxp.nyle.co.jp/marketing/" "301"
test_redirect "/marketing" "https://nxp.nyle.co.jp/marketing/" "301"
test_redirect "/marketing/" "" "200"
test_redirect "/ebook" "https://nxp.nyle.co.jp/ebook/" "301"
test_redirect "/ebook/" "https://nxp.nyle.co.jp/ebook/marketing/" "301"
test_redirect "/contact" "https://nxp.nyle.co.jp/contact/" "301"

if [ $FAILED -eq 0 ]; then
    echo "✅ All tests passed"
    exit 0
else
    echo "❌ $FAILED test(s) failed"
    exit 1
fi
```

---

## 5. チェックリスト

### Phase 1完了チェックリスト

- [ ] nginxからtrailing slash正規化を削除（本番・開発）
- [ ] ALBにtrailing slash正規化ルールを追加（Priority 20-27）
- [ ] nginx設定ファイルの文法チェック完了
- [ ] nginx再起動完了
- [ ] 全URLパターンで動作確認完了
- [ ] リダイレクト回数が1回以下
- [ ] パフォーマンステスト完了（150ms以上改善）
- [ ] ロールバック手順の確認

### Phase 2完了チェックリスト

- [ ] nginxから重複リダイレクトを削除
- [ ] 未使用ファイルを削除（nxp.conf, CloudFront Function, HTML redirects）
- [ ] `docs/infrastructure/alb-routing-rules.md` 作成
- [ ] `docs/infrastructure/nginx-configuration.md` 作成
- [ ] `docs/infrastructure/redirect-policy.md` 作成
- [ ] コミット・プッシュ完了
- [ ] 全テストがPASS

### Phase 3完了チェックリスト

- [ ] ALBルールのポート指定削除
- [ ] ALBルールの優先度整理
- [ ] Basic認証の見直し完了
- [ ] Terraform IaC導入（オプション）
- [ ] CloudWatch監視設定
- [ ] 自動テストの実装（GitHub Actions）
- [ ] 最終パフォーマンステスト完了
- [ ] ドキュメント更新

---

## 6. トラブルシューティング

### 問題1: 二重リダイレクトが解消されない

**症状**:
```
curl -I https://nxp.nyle.co.jp/marketing
HTTP/2 301 → http://...
HTTP/1.1 301 → https://...
```

**原因**: nginxのtrailing slash正規化が残っている

**解決策**:
```bash
# nginx設定を確認
cat /etc/nginx/conf.d/10-nxp-prod.conf | grep -A2 "location = /marketing"

# 該当箇所が残っている場合、削除して再起動
sudo systemctl reload nginx
```

### 問題2: ALBルールが機能しない

**症状**: nginxのリダイレクトが優先される

**原因**: ALBルールの優先度が低い

**解決策**:
- ALBルールのPriorityを確認
- リダイレクトルール（20-27）が転送ルール（81+）より優先されているか確認

### 問題3: 404エラーが発生

**症状**: `/marketing/` にアクセスすると404

**原因**: ファイルが存在しない、またはSPAフォールバックが機能していない

**解決策**:
```bash
# ファイル存在確認
ls -la /var/www/nxp.nyle.co.jp/marketing/

# nginx設定確認
cat /etc/nginx/conf.d/10-nxp-prod.conf | grep -A3 "location ^~ /marketing/"
```

### 問題4: キャッシュが効かない

**症状**: Assetsが毎回ダウンロードされる

**原因**: Cache-Controlヘッダーが適切に設定されていない

**解決策**:
```bash
# ヘッダー確認
curl -I https://nxp.nyle.co.jp/assets/img/logo.png | grep -i cache-control

# nginx設定確認
cat /etc/nginx/conf.d/10-nxp-prod.conf | grep -A5 "location ^~ /assets/"
```

---

## 7. 参考資料

- 分析レポート: `docs/analysis/url-normalization-redirect-analysis.md`
- ALBルール一覧: `docs/infrastructure/alb-routing-rules.md`
- nginx設定解説: `docs/infrastructure/nginx-configuration.md`

---

**実装ガイド終了**
