// Vercel Web Analytics for static sites (same behavior as the Next.js
// `<Analytics />` component / `inject()` from `@vercel/analytics`).
// Next.js: import { Analytics } from '@vercel/analytics/next'
(function () {
    if (typeof window === 'undefined') return;

    window.va = window.va || function () {
        (window.vaq = window.vaq || []).push(arguments);
    };

    var src = '/_vercel/insights/script.js';
    if (document.head.querySelector('script[src*="' + src + '"]')) return;

    var script = document.createElement('script');
    script.src = src;
    script.defer = true;
    script.dataset.sdkn = '@vercel/analytics';
    script.dataset.sdkv = '2.0.1';
    document.head.appendChild(script);
})();
