# GitHub Actionsでブログ記事を自動公開するシステムを構築した

## はじめに

複数のブログプラットフォームに記事を投稿する際、それぞれのサイトにログインして記事をコピー&ペーストするのは非常に手間がかかります。

この記事では、GitHub Actionsを使って複数のブログプラットフォームに自動で記事を公開するシステムを構築した方法を紹介します。

## システム概要

### 対応プラットフォーム

- **Zenn**: GitHub連携でmarkdownファイルを直接同期
- **Qiita**: Qiita CLIを使用
- **DEV.to**: Forem APIを使用
- **Hashnode**: GraphQL APIを使用
- **note**: 非公式REST APIを使用

### ワークフロー

1. `granizm-blog`リポジトリで記事を執筆
2. PRを作成 → 各プラットフォームに下書きとして投稿
3. PRをマージ → 各プラットフォームで記事を公開

## 技術的なポイント

### GitHub Actions の設定

```yaml
name: Publish Draft
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Publish to Platform
        run: ./scripts/publish.sh draft
```

### セキュリティ

各プラットフォームのAPIキーはGitHub Secretsで管理しています。

## まとめ

このシステムにより、一度の作業で複数のプラットフォームに記事を公開できるようになりました。

---

*この記事はテスト投稿です。*
# テスト更新 Fri Feb  6 07:48:26 UTC 2026


# テスト更新 Fri Feb  6 08:00:12 UTC 2026
