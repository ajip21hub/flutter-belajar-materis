import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "Flutter Belajar Materis",
  description: "Dokumentasi materi pembelajaran Flutter",
  base: '/',
  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Materi', link: '/day3' }
    ],

    sidebar: [
      {
        text: '📚 Materi Dasar',
        items: [
          { text: 'Day 3 - Grid User dari API', link: '/day3' },
          { text: 'Authentication', link: '/auth' }
        ]
      },
      {
        text: '🔧 Implementasi Fitur',
        items: [
          { text: '🌐 Multi-Language Implementation', link: '/implementasi/multi-language' },
          { text: '🔐 Environment Variables', link: '/implementasi/environment-variables' }
        ]
      },
      {
        text: '🚀 DevOps & CI/CD',
        items: [
          { text: 'Introduction to CI/CD', link: '/ci-cd-introduction' },
          { text: '📱 Flutter Production Guide', link: '/flutter_prod_guide' }
        ]
      },
      {
        text: '🛠️ Tools & Scripts',
        items: [
          { text: '🔨 Production Build Scripts', link: '/scripts' }
        ]
      },
      {
        text: '🔍 Analisis & Pengembangan Fitur',
        items: [
          { text: 'App Analysis Guide', link: '/app-analysis-guide' },
          { text: 'Feature Development Template', link: '/feature-development-template' },
          { text: 'Case Studies & Examples', link: '/case-studies-examples' }
        ]
      }
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/yourusername/yourrepo' }
    ]
  }
})
