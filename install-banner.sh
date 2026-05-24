#!/usr/bin/env bash

set -euo pipefail

PANEL_DIR="${PANEL_DIR:-/var/www/pterodactyl}"
RUN_BUILD="${RUN_BUILD:-1}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$PANEL_DIR/banner-installer-backups/$TIMESTAMP"

log() {
    echo -e "\033[1;36m[Banner Installer]\033[0m $1"
}

warn() {
    echo -e "\033[1;33m[Warning]\033[0m $1"
}

fail() {
    echo -e "\033[1;31m[Error]\033[0m $1"
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "Command '$1' tidak ditemukan. Install dulu dependency tersebut."
}

if [[ "$EUID" -ne 0 ]]; then
    fail "Jalankan script ini sebagai root. Contoh: sudo bash install-banner.sh"
fi

[[ -d "$PANEL_DIR" ]] || fail "Folder panel tidak ditemukan: $PANEL_DIR"
[[ -f "$PANEL_DIR/artisan" ]] || fail "File artisan tidak ditemukan. Pastikan PANEL_DIR mengarah ke root Pterodactyl Panel."

require_command php
require_command python3

cd "$PANEL_DIR"

log "Memulai instalasi banner untuk Pterodactyl Panel."
log "Panel directory: $PANEL_DIR"

mkdir -p "$BACKUP_DIR"

backup_file() {
    local relative_path="$1"
    if [[ -f "$relative_path" ]]; then
        mkdir -p "$BACKUP_DIR/$(dirname "$relative_path")"
        cp "$relative_path" "$BACKUP_DIR/$relative_path"
    fi
}

log "Membuat backup file yang akan diubah."
backup_file "routes/api-client.php"
backup_file "routes/admin.php"
backup_file "resources/scripts/routers/DashboardRouter.tsx"
backup_file "resources/views/layouts/admin.blade.php"

log "Menulis file backend dan frontend banner."
mkdir -p app/Models
mkdir -p app/Http/Controllers/Api/Client
mkdir -p app/Http/Controllers/Admin
mkdir -p resources/scripts/components/dashboard
mkdir -p resources/views/admin/banner

cat > app/Models/PanelBannerSetting.php <<'PHP'
<?php

namespace Pterodactyl\Models;

use Illuminate\Database\Eloquent\Model;

class PanelBannerSetting extends Model
{
    protected $table = 'panel_banner_settings';

    protected $fillable = [
        'enabled',
        'type',
        'title',
        'message',
    ];

    protected $casts = [
        'enabled' => 'boolean',
    ];
}
PHP

cat > app/Http/Controllers/Api/Client/PanelBannerController.php <<'PHP'
<?php

namespace Pterodactyl\Http\Controllers\Api\Client;

use Illuminate\Http\JsonResponse;
use Pterodactyl\Models\PanelBannerSetting;
use Pterodactyl\Http\Controllers\Api\Client\ClientApiController;

class PanelBannerController extends ClientApiController
{
    public function show(): JsonResponse
    {
        $banner = PanelBannerSetting::query()->first();

        return response()->json([
            'enabled' => (bool) optional($banner)->enabled,
            'type' => optional($banner)->type ?: 'info',
            'title' => optional($banner)->title,
            'message' => optional($banner)->message,
        ]);
    }
}
PHP

cat > app/Http/Controllers/Admin/PanelBannerController.php <<'PHP'
<?php

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\Http\Request;
use Illuminate\View\View;
use Illuminate\Http\RedirectResponse;
use Pterodactyl\Models\PanelBannerSetting;
use Pterodactyl\Http\Controllers\Controller;

class PanelBannerController extends Controller
{
    public function index(Request $request): View
    {
        abort_unless($request->user() && $request->user()->root_admin, 403);

        $banner = $this->getBanner();

        return view('admin.banner.index', [
            'banner' => $banner,
        ]);
    }

    public function update(Request $request): RedirectResponse
    {
        abort_unless($request->user() && $request->user()->root_admin, 403);

        $data = $request->validate([
            'enabled' => ['nullable', 'boolean'],
            'type' => ['required', 'in:info,warning,promo'],
            'title' => ['nullable', 'string', 'max:120'],
            'message' => ['nullable', 'string', 'max:1000'],
        ]);

        $banner = $this->getBanner();
        $banner->update([
            'enabled' => $request->boolean('enabled'),
            'type' => $data['type'],
            'title' => $data['title'] ?? null,
            'message' => $data['message'] ?? null,
        ]);

        return redirect('/admin/banner')->with('success', 'Pengaturan banner berhasil disimpan.');
    }

    private function getBanner(): PanelBannerSetting
    {
        $banner = PanelBannerSetting::query()->first();

        if (!$banner) {
            $banner = PanelBannerSetting::query()->create([
                'enabled' => false,
                'type' => 'info',
                'title' => 'Informasi',
                'message' => 'Selamat datang di panel.',
            ]);
        }

        return $banner;
    }
}
PHP

cat > resources/scripts/components/dashboard/PanelBanner.tsx <<'TSX'
import React, { useEffect, useState } from 'react';
import http from '@/api/http';

type BannerType = 'info' | 'warning' | 'promo';

interface BannerData {
    enabled: boolean;
    type: BannerType;
    title?: string | null;
    message?: string | null;
}

const typeStyles: Record<BannerType, { border: string; label: string }> = {
    info: {
        border: 'border-blue-500',
        label: 'Informasi',
    },
    warning: {
        border: 'border-yellow-500',
        label: 'Warning',
    },
    promo: {
        border: 'border-green-500',
        label: 'Promosi',
    },
};

export default function PanelBanner() {
    const [banner, setBanner] = useState<BannerData | null>(null);
    const [hidden, setHidden] = useState(false);

    useEffect(() => {
        http.get('/api/client/panel-banner')
            .then(({ data }) => setBanner(data))
            .catch(() => setBanner(null));
    }, []);

    if (!banner || !banner.enabled || hidden || !banner.message) {
        return null;
    }

    const style = typeStyles[banner.type] || typeStyles.info;

    return (
        <div className={`relative mb-4 rounded bg-white p-4 pl-5 shadow border-l-4 ${style.border}`}>
            <button
                type={'button'}
                onClick={() => setHidden(true)}
                className={'absolute right-3 top-3 text-gray-400 hover:text-gray-700 focus:outline-none'}
                aria-label={'Tutup banner'}
            >
                ✕
            </button>

            <div className={'pr-8'}>
                <div className={'mb-1 text-sm font-semibold text-gray-800'}>
                    {banner.title || style.label}
                </div>

                <div className={'text-sm leading-relaxed text-gray-600'}>
                    {banner.message}
                </div>
            </div>
        </div>
    );
}
TSX

cat > resources/views/admin/banner/index.blade.php <<'BLADE'
@extends('layouts.admin')

@section('title')
    Panel Banner
@endsection

@section('content-header')
    <h1>Panel Banner<small>Atur banner informasi di halaman client.</small></h1>
    <ol class="breadcrumb">
        <li><a href="{{ url('/admin') }}">Admin</a></li>
        <li class="active">Panel Banner</li>
    </ol>
@endsection

@section('content')
    <div class="row">
        <div class="col-xs-12">
            @if (session('success'))
                <div class="alert alert-success">
                    {{ session('success') }}
                </div>
            @endif

            @if ($errors->any())
                <div class="alert alert-danger">
                    <strong>Gagal menyimpan pengaturan.</strong>
                    <ul style="margin-top: 8px;">
                        @foreach ($errors->all() as $error)
                            <li>{{ $error }}</li>
                        @endforeach
                    </ul>
                </div>
            @endif

            <div class="box box-primary">
                <div class="box-header with-border">
                    <h3 class="box-title">Pengaturan Banner</h3>
                </div>

                <form method="POST" action="{{ url('/admin/banner') }}">
                    @csrf

                    <div class="box-body">
                        <div class="checkbox">
                            <label>
                                <input type="checkbox" name="enabled" value="1" {{ old('enabled', $banner->enabled) ? 'checked' : '' }}>
                                Aktifkan banner
                            </label>
                        </div>

                        <div class="form-group">
                            <label for="type">Jenis Banner</label>
                            <select id="type" name="type" class="form-control">
                                <option value="info" {{ old('type', $banner->type) === 'info' ? 'selected' : '' }}>Informasi</option>
                                <option value="warning" {{ old('type', $banner->type) === 'warning' ? 'selected' : '' }}>Warning</option>
                                <option value="promo" {{ old('type', $banner->type) === 'promo' ? 'selected' : '' }}>Promosi</option>
                            </select>
                            <p class="text-muted" style="margin-top: 6px;">Informasi = biru, Warning = kuning, Promosi = hijau.</p>
                        </div>

                        <div class="form-group">
                            <label for="title">Judul Banner</label>
                            <input
                                id="title"
                                type="text"
                                name="title"
                                class="form-control"
                                maxlength="120"
                                value="{{ old('title', $banner->title) }}"
                                placeholder="Contoh: Maintenance Panel"
                            >
                        </div>

                        <div class="form-group">
                            <label for="message">Isi Banner</label>
                            <textarea
                                id="message"
                                name="message"
                                class="form-control"
                                rows="5"
                                maxlength="1000"
                                placeholder="Tulis isi banner di sini..."
                            >{{ old('message', $banner->message) }}</textarea>
                        </div>

                        <div class="callout callout-info">
                            <h4>Preview perilaku banner</h4>
                            <p>Banner bisa ditutup dengan tombol X oleh user. Setelah halaman di-refresh, web dibuka ulang, atau user login ulang, banner akan tampil kembali.</p>
                        </div>
                    </div>

                    <div class="box-footer">
                        <button type="submit" class="btn btn-primary">Simpan Banner</button>
                        <a href="{{ url('/') }}" target="_blank" class="btn btn-default">Lihat Halaman Client</a>
                    </div>
                </form>
            </div>
        </div>
    </div>
@endsection
BLADE

log "Membuat migration database jika belum ada."
if find database/migrations -maxdepth 1 -name '*create_panel_banner_settings_table.php' | grep -q .; then
    warn "Migration panel_banner_settings sudah ada, dilewati."
else
    MIGRATION_FILE="database/migrations/$(date +%Y_%m_%d_%H%M%S)_create_panel_banner_settings_table.php"
    cat > "$MIGRATION_FILE" <<'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

class CreatePanelBannerSettingsTable extends Migration
{
    public function up()
    {
        if (!Schema::hasTable('panel_banner_settings')) {
            Schema::create('panel_banner_settings', function (Blueprint $table) {
                $table->id();
                $table->boolean('enabled')->default(false);
                $table->string('type')->default('info');
                $table->string('title')->nullable();
                $table->text('message')->nullable();
                $table->timestamps();
            });

            DB::table('panel_banner_settings')->insert([
                'enabled' => false,
                'type' => 'info',
                'title' => 'Informasi',
                'message' => 'Selamat datang di panel.',
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
    }

    public function down()
    {
        Schema::dropIfExists('panel_banner_settings');
    }
}
PHP
fi

log "Menambahkan route API dan route admin."
[[ -f routes/api-client.php ]] || fail "routes/api-client.php tidak ditemukan."
[[ -f routes/admin.php ]] || fail "routes/admin.php tidak ditemukan."

if ! grep -q "PTERODACTYL_BANNER_API_BEGIN" routes/api-client.php; then
    cat >> routes/api-client.php <<'PHP'

// PTERODACTYL_BANNER_API_BEGIN
\Illuminate\Support\Facades\Route::get('/panel-banner', [\Pterodactyl\Http\Controllers\Api\Client\PanelBannerController::class, 'show']);
// PTERODACTYL_BANNER_API_END
PHP
else
    warn "Route API banner sudah ada, dilewati."
fi

if ! grep -q "PTERODACTYL_BANNER_ADMIN_BEGIN" routes/admin.php; then
    cat >> routes/admin.php <<'PHP'

// PTERODACTYL_BANNER_ADMIN_BEGIN
\Illuminate\Support\Facades\Route::get('/banner', [\Pterodactyl\Http\Controllers\Admin\PanelBannerController::class, 'index']);
\Illuminate\Support\Facades\Route::post('/banner', [\Pterodactyl\Http\Controllers\Admin\PanelBannerController::class, 'update']);
// PTERODACTYL_BANNER_ADMIN_END
PHP
else
    warn "Route admin banner sudah ada, dilewati."
fi

log "Memasang komponen banner ke DashboardRouter.tsx."
[[ -f resources/scripts/routers/DashboardRouter.tsx ]] || fail "resources/scripts/routers/DashboardRouter.tsx tidak ditemukan."

python3 <<'PY'
from pathlib import Path
import re
import sys

path = Path('resources/scripts/routers/DashboardRouter.tsx')
text = path.read_text()

import_line = "import PanelBanner from '@/components/dashboard/PanelBanner';"
if import_line not in text:
    imports = list(re.finditer(r"^import\s+.+?;\s*$", text, flags=re.MULTILINE))
    if imports:
        pos = imports[-1].end()
        text = text[:pos] + "\n" + import_line + text[pos:]
    else:
        text = import_line + "\n" + text

if 'PTERODACTYL_BANNER_DASHBOARD_BEGIN' not in text:
    match = re.search(r"<PageContentBlock\b[^>]*>", text)
    if not match:
        print('Tidak menemukan <PageContentBlock> di DashboardRouter.tsx', file=sys.stderr)
        sys.exit(1)

    snippet = "\n            {/* PTERODACTYL_BANNER_DASHBOARD_BEGIN */}\n            <PanelBanner />\n            {/* PTERODACTYL_BANNER_DASHBOARD_END */}"
    text = text[:match.end()] + snippet + text[match.end():]

path.write_text(text)
PY

log "Menambahkan menu admin secara best-effort."
python3 <<'PY'
from pathlib import Path
import re

path = Path('resources/views/layouts/admin.blade.php')
if not path.exists():
    print('resources/views/layouts/admin.blade.php tidak ditemukan, menu admin dilewati. Halaman tetap tersedia di /admin/banner')
    raise SystemExit(0)

text = path.read_text()
if 'PTERODACTYL_BANNER_MENU_BEGIN' in text:
    raise SystemExit(0)

item = """
                    <!-- PTERODACTYL_BANNER_MENU_BEGIN -->
                    <li class=\"{{ request()->is('admin/banner') ? 'active' : '' }}\">
                        <a href=\"{{ url('/admin/banner') }}\">
                            <i class=\"fa fa-bullhorn\"></i> <span>Panel Banner</span>
                        </a>
                    </li>
                    <!-- PTERODACTYL_BANNER_MENU_END -->
"""

pattern = re.compile(r"(<ul[^>]*class=[\"'][^\"']*sidebar-menu[^\"']*[\"'][^>]*>)([\s\S]*?)(</ul>)", re.IGNORECASE)
match = pattern.search(text)
if match:
    new_text = text[:match.start(3)] + item + text[match.start(3):]
    path.write_text(new_text)
    print('Menu Panel Banner berhasil ditambahkan ke sidebar admin.')
else:
    print('Sidebar admin tidak dikenali, menu dilewati. Halaman tetap tersedia di /admin/banner')
PY

log "Menjalankan migration."
php artisan migrate --force

log "Membersihkan cache Laravel."
php artisan optimize:clear || true
php artisan view:clear || true
php artisan route:clear || true
php artisan config:clear || true

if [[ -d node_modules ]]; then
    log "node_modules sudah ada."
fi

if [[ "$RUN_BUILD" == "1" ]]; then
    log "Build ulang asset panel."
    if command -v yarn >/dev/null 2>&1; then
        yarn install --frozen-lockfile || yarn install
        yarn build:production || yarn build
    elif command -v npm >/dev/null 2>&1; then
        npm install
        npm run build:production || npm run build
    else
        fail "Yarn/NPM tidak ditemukan. Install Node.js + Yarn, lalu build manual."
    fi
else
    warn "RUN_BUILD=0, proses build dilewati. Jalankan build manual sebelum digunakan."
fi

if id www-data >/dev/null 2>&1; then
    chown -R www-data:www-data \
        app/Models/PanelBannerSetting.php \
        app/Http/Controllers/Api/Client/PanelBannerController.php \
        app/Http/Controllers/Admin/PanelBannerController.php \
        resources/scripts/components/dashboard/PanelBanner.tsx \
        resources/views/admin/banner || true
fi

log "Instalasi selesai."
echo ""
echo "Backup tersimpan di: $BACKUP_DIR"
echo "Buka halaman admin: /admin/banner"
echo "Jika banner belum muncul, jalankan: php artisan optimize:clear && yarn build:production"
