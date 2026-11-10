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
      { text: 'Materi', link: '/day3' },
      { text: 'Lanjutan', link: '/lanjutan/' }
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
      },
      {
        text: '🚀 Pelatihan Lanjutan — Advanced (5 Hari)',
        collapsed: false,
        items: [
          { text: 'Overview & Silabus', link: '/lanjutan/' },
          { text: 'Hari 1 - Arsitektur, Dart 3.13 & Riverpod 3', link: '/lanjutan/day1' },
          { text: 'Hari 2 - Jaringan Aman & go_router', link: '/lanjutan/day2' },
          { text: 'Hari 3 - Offline-First, Background & Real-time', link: '/lanjutan/day3' },
          { text: 'Hari 4 - Kualitas, Performa & Native', link: '/lanjutan/day4' },
          { text: 'Hari 5 - Produksi, AI & Rilis', link: '/lanjutan/day5' }
        ]
      }
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/yourusername/yourrepo' }
    ]
  }
})
