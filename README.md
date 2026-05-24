# Pterodactyl Panel Banner Installer

Installer otomatis untuk menambahkan sistem banner informasi ke Pterodactyl Panel.

## Fitur

- Banner dapat diatur dari halaman admin: `/admin/banner`
- Pilihan jenis banner:
  - Informasi: garis kiri biru
  - Warning: garis kiri kuning
  - Promosi: garis kiri hijau
- Background banner putih
- Tombol `X` untuk menutup banner sementara
- Setelah refresh, buka web ulang, atau login ulang, banner tampil kembali
- Installer standalone, cocok dipanggil dari GitHub Raw
- Ada backup file sebelum patch
- Ada uninstaller

## Struktur file

```txt
pterodactyl-banner-installer/
├── install-banner.sh
├── uninstall-banner.sh
├── README.md
└── files/
    ├── AdminPanelBannerController.php
    ├── ClientPanelBannerController.php
    ├── PanelBannerSetting.php
    ├── PanelBanner.tsx
    └── admin-banner-index.blade.php
```

Folder `files/` hanya referensi kode sumber. Installer utama `install-banner.sh` sudah standalone dan sudah berisi semua kode di dalamnya.

## Cara upload ke GitHub

1. Extract ZIP ini.
2. Buat repository GitHub baru, misalnya:

```txt
pterodactyl-banner-installer
```

3. Upload semua isi folder ke repository.
4. Pastikan file `install-banner.sh` berada di root repository.

## Cara install dari GitHub Raw

Ganti `USERNAME` dan `REPO` sesuai repository Tuan:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/USERNAME/REPO/main/install-banner.sh)
```

Contoh:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/coc-demonnz/pterodactyl-banner-installer/main/install-banner.sh)
```

Jika branch GitHub memakai `master`, ganti `main` menjadi `master`.

## Jika folder panel bukan `/var/www/pterodactyl`

Gunakan environment variable `PANEL_DIR`:

```bash
PANEL_DIR=/path/ke/pterodactyl bash <(curl -sSL https://raw.githubusercontent.com/USERNAME/REPO/main/install-banner.sh)
```

## Cara pakai setelah install

1. Login sebagai admin/root admin.
2. Buka:

```txt
https://domain-panel-tuan.com/admin/banner
```

3. Aktifkan banner.
4. Pilih jenis banner.
5. Isi judul dan pesan.
6. Klik `Simpan Banner`.
7. Buka dashboard client untuk melihat hasilnya.

## Build manual jika diperlukan

Jika setelah install banner belum muncul, jalankan:

```bash
cd /var/www/pterodactyl
php artisan optimize:clear
yarn build:production
```

Jika server memakai npm:

```bash
npm run build:production
```

## Uninstall

Dari GitHub Raw:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/USERNAME/REPO/main/uninstall-banner.sh)
```

Uninstall tanpa menghapus data database adalah default.

Untuk menghapus tabel database juga:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/USERNAME/REPO/main/uninstall-banner.sh) --drop-table
```

## Catatan keamanan

Jangan menjalankan script dari repository yang tidak Tuan percaya. Sebelum install di panel production, sangat disarankan membuat snapshot VPS atau backup panel.

Installer otomatis mengubah file berikut:

```txt
routes/api-client.php
routes/admin.php
resources/scripts/routers/DashboardRouter.tsx
resources/views/layouts/admin.blade.php
```

Installer juga membuat file baru berikut:

```txt
app/Models/PanelBannerSetting.php
app/Http/Controllers/Api/Client/PanelBannerController.php
app/Http/Controllers/Admin/PanelBannerController.php
resources/scripts/components/dashboard/PanelBanner.tsx
resources/views/admin/banner/index.blade.php
database/migrations/*_create_panel_banner_settings_table.php
```

Backup otomatis disimpan di:

```txt
/var/www/pterodactyl/banner-installer-backups/
```

## Troubleshooting

### 403 saat buka `/admin/banner`

Pastikan akun yang dipakai adalah root admin Pterodactyl.

### Halaman `/admin/banner` tidak ditemukan

Jalankan:

```bash
cd /var/www/pterodactyl
php artisan route:clear
php artisan optimize:clear
```

### Banner tidak muncul di dashboard client

Pastikan banner sudah aktif di `/admin/banner`, lalu jalankan:

```bash
cd /var/www/pterodactyl
yarn build:production
php artisan optimize:clear
```

### Error saat build

Coba jalankan:

```bash
cd /var/www/pterodactyl
yarn install
yarn build:production
```

Jika panel Tuan adalah fork/custom theme, file `DashboardRouter.tsx` atau layout admin bisa berbeda. Dalam kondisi itu patch otomatis mungkin perlu disesuaikan manual.
