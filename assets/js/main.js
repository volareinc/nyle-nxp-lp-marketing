jQuery(function () {
  //スムーススクロール
  $('a[href^="#"]').click(function() {
    // スクロールの速度
    let speed = 400; // ミリ秒で記述
    let href = $(this).attr("href");
    let target = $(href == "#" || href == "" ? 'html' : href);
    let position = target.offset().top;
    $('body,html').animate({
      scrollTop: position
    }, speed, 'swing');
    return false;
  });
});

document.addEventListener('DOMContentLoaded', () => {
  const target = document.getElementById('section-content');
  const footer = document.querySelector('footer');
  const spCta = document.getElementById('sp-cta');

  // 初期状態
  spCta.style.opacity = '0';
  spCta.style.pointerEvents = 'none';
  spCta.style.transition = 'opacity 0.5s ease';

  let footerVisible = false;

  // section-content監視
  const sectionObserver = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (entry.isIntersecting && !footerVisible) {
        spCta.style.opacity = '1';
        spCta.style.pointerEvents = 'all';
      } else {
        spCta.style.opacity = '0';
        spCta.style.pointerEvents = 'none';
      }
    });
  }, {
    root: null,
    threshold: 0,
  });

  // footer監視
  const footerObserver = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        footerVisible = true;
        spCta.style.opacity = '0';
        spCta.style.pointerEvents = 'none';
      } else {
        footerVisible = false;
      }
    });
  }, {
    root: null,
    threshold: 0,
  });

  sectionObserver.observe(target);
  footerObserver.observe(footer);
});
