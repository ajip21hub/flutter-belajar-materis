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
        text: 'Materi Pembelajaran',
        items: [
          { text: 'Day 3 - Grid User dari API', link: '/day3' },
          { text: 'Authentication dengan JWT', link: '/auth' }
        ]
      }
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/yourusername/yourrepo' }
    ]
  }
})
