/**
 * CloudFront Function for URL Redirects
 * nxp.nyle.co.jp のリダイレクト処理
 *
 * デプロイ方法:
 * 1. CloudFront Console > Functions
 * 2. "Create function" > 名前: nxp-redirect-function
 * 3. このコードを貼り付け
 * 4. "Publish" してから CloudFront Distribution に関連付け（Viewer Request）
 */

function handler(event) {
    var request = event.request;
    var uri = request.uri;
    var host = request.headers.host.value;

    // 旧ドメインからのアクセス（x.seohacks.net → nxp.nyle.co.jp）
    if (host === 'x.seohacks.net') {
        var newUri = uri;

        // パスマッピング
        if (uri === '/' || uri === '') {
            newUri = '/marketing/';
        } else if (uri.startsWith('/nxp-contact')) {
            newUri = uri.replace('/nxp-contact', '/contact');
        } else if (uri.startsWith('/nxp-service')) {
            newUri = uri.replace('/nxp-service', '/ebook/marketing');
        }

        return {
            statusCode: 301,
            statusDescription: 'Moved Permanently',
            headers: {
                'location': { value: 'https://nxp.nyle.co.jp' + newUri }
            }
        };
    }

    // 新ドメイン内のリダイレクト
    if (host === 'nxp.nyle.co.jp') {
        // ルートアクセス → /marketing/
        if (uri === '/' || uri === '') {
            return {
                statusCode: 302,
                statusDescription: 'Found',
                headers: {
                    'location': { value: '/marketing/' }
                }
            };
        }

        // /ebook/ → /ebook/marketing/
        if (uri === '/ebook' || uri === '/ebook/') {
            return {
                statusCode: 302,
                statusDescription: 'Found',
                headers: {
                    'location': { value: '/ebook/marketing/' }
                }
            };
        }

        // /entry/form.html → /entry/form/ (拡張子削除)
        if (uri === '/entry/form.html') {
            return {
                statusCode: 301,
                statusDescription: 'Moved Permanently',
                headers: {
                    'location': { value: '/entry/form/' }
                }
            };
        }
    }

    // 拡張子がない場合、/index.html を付与（クリーンURL対応）
    if (!uri.includes('.') && !uri.endsWith('/')) {
        request.uri = uri + '/index.html';
    } else if (uri.endsWith('/')) {
        request.uri = uri + 'index.html';
    }

    return request;
}
