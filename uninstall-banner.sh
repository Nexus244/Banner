#!/usr/bin/env bash

set -euo pipefail

PANEL_DIR="${PANEL_DIR:-/var/www/pterodactyl}"
RUN_BUILD="${RUN_BUILD:-1}"
DROP_TABLE="0"

for arg in "$@"; do
    case "$arg" in
        --drop-table)
            DROP_TABLE="1"
            ;;
        *)
            echo "Argumen tidak dikenal: $arg"
            echo "Gunakan: bash uninstall-banner.sh [--drop-table]"
            exit 1
            ;;
    esac
done

log() {
    echo -e "\033[1;36m[Banner Uninstaller]\033[0m $1"
}

warn() {
    echo -e "\033[1;33m[Warning]\033[0m $1"
}

fail() {
    echo -e "\033[1;31m[Error]\033[0m $1"
    exit 1
}

if [[ "$EUID" -ne 0 ]]; then
    fail "Jalankan script ini sebagai root. Contoh: sudo bash uninstall-banner.sh"
fi

[[ -d "$PANEL_DIR" ]] || fail "Folder panel tidak ditemukan: $PANEL_DIR"
[[ -f "$PANEL_DIR/artisan" ]] || fail "File artisan tidak ditemukan. Pastikan PANEL_DIR mengarah ke root Pterodactyl Panel."

cd "$PANEL_DIR"

log "Menghapus file banner."
rm -f app/Models/PanelBannerSetting.php
rm -f app/Http/Controllers/Api/Client/PanelBannerController.php
rm -f app/Http/Controllers/Admin/PanelBannerController.php
rm -f resources/scripts/components/dashboard/PanelBanner.tsx
rm -rf resources/views/admin/banner

log "Menghapus route banner."
if [[ -f routes/api-client.php ]]; then
    perl -0pi -e 's/\n?\/\/ PTERODACTYL_BANNER_API_BEGIN.*?\/\/ PTERODACTYL_BANNER_API_END\n?/\n/s' routes/api-client.php
fi

if [[ -f routes/admin.php ]]; then
    perl -0pi -e 's/\n?\/\/ PTERODACTYL_BANNER_ADMIN_BEGIN.*?\/\/ PTERODACTYL_BANNER_ADMIN_END\n?/\n/s' routes/admin.php
fi

log "Menghapus komponen banner dari DashboardRouter.tsx."
if [[ -f resources/scripts/routers/DashboardRouter.tsx ]]; then
    perl -0pi -e "s/^import PanelBanner from '\@\/components\/dashboard\/PanelBanner';\n//m" resources/scripts/routers/DashboardRouter.tsx
    perl -0pi -e 's/\n?\s*\{\/\* PTERODACTYL_BANNER_DASHBOARD_BEGIN \*\/\}\n\s*<PanelBanner \/>\n\s*\{\/\* PTERODACTYL_BANNER_DASHBOARD_END \*\/\}//s' resources/scripts/routers/DashboardRouter.tsx
fi

log "Menghapus menu admin best-effort."
if [[ -f resources/views/layouts/admin.blade.php ]]; then
    perl -0pi -e 's/\n?\s*<!-- PTERODACTYL_BANNER_MENU_BEGIN -->.*?<!-- PTERODACTYL_BANNER_MENU_END -->\n?//s' resources/views/layouts/admin.blade.php
fi

if [[ "$DROP_TABLE" == "1" ]]; then
    log "Menghapus tabel panel_banner_settings."
    php artisan tinker --execute="Schema::dropIfExists('panel_banner_settings');" || warn "Gagal drop table via tinker. Hapus manual jika perlu."
else
    warn "Tabel database tidak dihapus. Gunakan --drop-table jika ingin menghapus data banner."
fi

log "Membersihkan cache Laravel."
php artisan optimize:clear || true
php artisan view:clear || true
php artisan route:clear || true
php artisan config:clear || true

if [[ "$RUN_BUILD" == "1" ]]; then
    log "Build ulang asset panel."
    if command -v yarn >/dev/null 2>&1; then
        yarn build:production || yarn build
    elif command -v npm >/dev/null 2>&1; then
        npm run build:production || npm run build
    else
        warn "Yarn/NPM tidak ditemukan. Build manual diperlukan."
    fi
else
    warn "RUN_BUILD=0, proses build dilewati."
fi

log "Uninstall selesai."
