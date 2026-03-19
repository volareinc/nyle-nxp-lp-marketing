document.addEventListener('DOMContentLoaded', () => {
  const spCta = document.getElementById('sp-cta');
  const SCROLL_THRESHOLD = 1000;

  // sp-cta要素が存在しない場合は処理をスキップ
  if (!spCta) {
    return;
  }

  // 初期状態
  spCta.style.opacity = '0';
  spCta.style.pointerEvents = 'none';
  spCta.style.transition = 'opacity 0.5s ease';

  // スクロール位置を監視
  const handleScroll = () => {
    const scrollY = window.scrollY || window.pageYOffset;

    if (scrollY > SCROLL_THRESHOLD) {
      spCta.style.opacity = '1';
      spCta.style.pointerEvents = 'all';
    } else {
      spCta.style.opacity = '0';
      spCta.style.pointerEvents = 'none';
    }
  };

  // スクロールイベントリスナー
  window.addEventListener('scroll', handleScroll);

  // 初期表示時にもチェック
  handleScroll();
});
