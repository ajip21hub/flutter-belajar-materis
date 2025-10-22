# Flutter Belajar Materis - Dokumentasi Online

Dokumentasi materi pembelajaran Flutter dengan VitePress yang dapat di-deploy ke Vercel.

## 🚀 Quick Start

### Development

Jalankan dokumentasi secara lokal:

```bash
npm install
npm run docs:dev
```

Buka browser di `http://localhost:5173`

### Build

Build dokumentasi untuk production:

```bash
npm run docs:build
```

### Preview

Preview hasil build:

```bash
npm run docs:preview
```

## 📦 Deploy ke Vercel

### Cara 1: Via Vercel Dashboard (Recommended)

1. Push project ini ke GitHub repository
2. Buka [vercel.com](https://vercel.com) dan login
3. Klik **Add New Project**
4. Import repository GitHub Anda
5. Vercel akan otomatis detect konfigurasi dari `vercel.json`
6. Klik **Deploy**

### Cara 2: Via Vercel CLI

```bash
# Install Vercel CLI
npm i -g vercel

# Deploy
vercel
```

## 📝 Menambah Materi Baru

### 1. Tambahkan file markdown baru

Buat file `.md` baru di folder `docs/`, contoh:

```bash
# Buat file day4.md
touch docs/day4.md
```

### 2. Update konfigurasi sidebar

Edit `docs/.vitepress/config.mjs`:

```js
sidebar: [
  {
    text: 'Materi Pembelajaran',
    items: [
      { text: 'Day 3 - Grid User dari API', link: '/day3' },
      { text: 'Day 4 - Materi Baru', link: '/day4' }  // ← Tambahkan di sini
    ]
  }
]
```

### 3. Commit dan push

```bash
git add .
git commit -m "Add day4 material"
git push
```

Vercel akan otomatis rebuild dan deploy!

## 📁 Struktur Folder

```
materis/
├── docs/
│   ├── .vitepress/
│   │   └── config.mjs       # Konfigurasi VitePress & navigation
│   ├── index.md             # Homepage
│   ├── day3.md              # Materi Day 3
│   └── day4.md              # Materi Day 4 (tambah nanti)
├── package.json
├── vercel.json              # Konfigurasi deployment Vercel
└── README.md
```

## 🎨 Kustomisasi

### Mengubah Judul & Deskripsi

Edit `docs/.vitepress/config.mjs`:

```js
export default defineConfig({
  title: "Judul Anda",
  description: "Deskripsi Anda",
  // ...
})
```

### Mengubah Homepage

Edit `docs/index.md` sesuai kebutuhan.

### Menambah Link GitHub

Edit `docs/.vitepress/config.mjs`:

```js
socialLinks: [
  { icon: 'github', link: 'https://github.com/username/repo' }
]
```

## 📚 Dokumentasi VitePress

Untuk fitur lebih lanjut, lihat [VitePress Documentation](https://vitepress.dev)

## 🔧 Troubleshooting

### Port sudah digunakan

Jika port 5173 sudah digunakan, VitePress akan otomatis menggunakan port lain.

### Build error di Vercel

Pastikan `vercel.json` sudah ter-commit ke repository.

### Materi tidak muncul di sidebar

Periksa kembali path di `config.mjs` harus match dengan nama file di folder `docs/`.
