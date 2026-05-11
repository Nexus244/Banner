#!/bin/bash

clear

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PANEL_DIR="/var/www/pterodactyl"

install_banner() {

clear

echo -e "${GREEN}"
echo "======================================="
echo " INSTALL DYNAMIC BANNER"
echo "======================================="
echo -e "${NC}"

cd $PANEL_DIR || {
    echo -e "${RED}Pterodactyl tidak ditemukan!${NC}"
    exit 1
}

echo -e "${YELLOW}[1/10] Backup file...${NC}"

cp -r resources resources.banner.backup
cp -r routes routes.banner.backup
cp -r app app.banner.backup

echo -e "${YELLOW}[2/10] Membuat migration...${NC}"

php artisan make:model Announcement -m

LATEST=$(ls -t database/migrations/*create_announcements_table.php | head -n 1)

cat > $LATEST << 'EOF'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('announcements', function (Blueprint $table) {
            $table->id();

            $table->string('type')->default('info');

            $table->text('message');

            $table->boolean('enabled')->default(true);

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('announcements');
    }
};
EOF

echo -e "${YELLOW}[3/10] Menjalankan migration...${NC}"

php artisan migrate

echo -e "${YELLOW}[4/10] Membuat API Controller...${NC}"

mkdir -p app/Http/Controllers/Api/Client

cat > app/Http/Controllers/Api/Client/AnnouncementController.php << 'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Api\Client;

use Illuminate\Http\JsonResponse;
use Pterodactyl\Models\Announcement;

class AnnouncementController
{
    public function index(): JsonResponse
    {
        return response()->json(
            Announcement::where('enabled', true)->latest()->get()
        );
    }
}
EOF

echo -e "${YELLOW}[5/10] Menambahkan API Route...${NC}"

grep -q "announcements" routes/api-client.php

if [ $? -ne 0 ]; then

echo "
Route::get('/announcements', [
    \Pterodactyl\Http\Controllers\Api\Client\AnnouncementController::class,
    'index'
]);
" >> routes/api-client.php

fi
echo -e "${YELLOW}[6/10] Membuat Banner React...${NC}"

mkdir -p resources/scripts/components

cat > resources/scripts/components/AnnouncementBanner.tsx << 'EOF'
import React, { useEffect, useState } from 'react';
import axios from 'axios';

export default function AnnouncementBanner() {

    const [closed, setClosed] = useState(false);

    const [announcements, setAnnouncements] = useState([]);

    useEffect(() => {
        axios.get('/api/client/announcements')
            .then((res) => {
                setAnnouncements(res.data);
            });
    }, []);

    if (closed || announcements.length === 0) {
        return null;
    }

    return (
        <>
            {announcements.map((a: any) => (

                <div
                    key={a.id}
                    style={{
                        background:
                            a.type === 'warning'
                                ? '#f59e0b'
                                : a.type === 'promo'
                                ? '#10b981'
                                : '#2563eb',

                        padding: '15px',
                        borderRadius: '10px',
                        marginBottom: '15px',
                        color: 'white',

                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'center',
                    }}
                >
                    <div>

                        <div
                            style={{
                                fontWeight: 'bold',
                                marginBottom: '5px',
                                textTransform: 'uppercase',
                            }}
                        >
                            {a.type}
                        </div>

                        <div>
                            {a.message}
                        </div>

                    </div>

                    <button
                        onClick={() => setClosed(true)}
                        style={{
                            background: 'transparent',
                            border: 'none',
                            color: 'white',
                            fontSize: '18px',
                            cursor: 'pointer',
                        }}
                    >
                        ✕
                    </button>
                </div>

            ))}
        </>
    );
}
EOF

echo -e "${YELLOW}[7/10] Inject dashboard...${NC}"

TARGET="resources/scripts/components/dashboard/DashboardContainer.tsx"

grep -q "AnnouncementBanner" "$TARGET"

if [ $? -ne 0 ]; then

sed -i "1i import AnnouncementBanner from '@/components/AnnouncementBanner';" "$TARGET"

sed -i '/return (/a\
            <AnnouncementBanner />
' "$TARGET"

fi

echo -e "${YELLOW}[8/10] Build panel...${NC}"

yarn build:production

echo -e "${YELLOW}[9/10] Clear cache...${NC}"

php artisan optimize:clear

echo -e "${YELLOW}[10/10] Restart service...${NC}"

systemctl restart nginx
systemctl restart redis-server
systemctl restart pteroq

clear

echo -e "${GREEN}"
echo "======================================="
echo " INSTALL SUCCESS"
echo "======================================="
echo -e "${NC}"

echo ""
echo "Contoh tambah banner:"
echo ""
echo "INSERT INTO announcements"
echo "(type, message, enabled)"
echo "VALUES"
echo "('promo', 'Diskon VPS 50%', 1);"

}
uninstall_banner() {

clear

echo -e "${RED}"
echo "======================================="
echo " UNINSTALL DYNAMIC BANNER"
echo "======================================="
echo -e "${NC}"

cd $PANEL_DIR || exit

echo -e "${YELLOW}[1/6] Menghapus React banner...${NC}"

rm -f resources/scripts/components/AnnouncementBanner.tsx

echo -e "${YELLOW}[2/6] Membersihkan dashboard...${NC}"

TARGET="resources/scripts/components/dashboard/DashboardContainer.tsx"

sed -i "/AnnouncementBanner/d" "$TARGET"

sed -i "/<AnnouncementBanner \/>/d" "$TARGET"

echo -e "${YELLOW}[3/6] Menghapus API route...${NC}"

sed -i '/announcements/d' routes/api-client.php

echo -e "${YELLOW}[4/6] Rollback database...${NC}"

php artisan migrate:rollback --step=1

echo -e "${YELLOW}[5/6] Build panel...${NC}"

yarn build:production

echo -e "${YELLOW}[6/6] Restart service...${NC}"

systemctl restart nginx
systemctl restart redis-server
systemctl restart pteroq

clear

echo -e "${GREEN}"
echo "======================================="
echo " UNINSTALL SUCCESS"
echo "======================================="
echo -e "${NC}"

}

clear

echo "======================================="
echo " PTERODACTYL DYNAMIC BANNER"
echo "======================================="
echo ""
echo "1. Install Banner"
echo "2. Uninstall Banner"
echo ""

read -p "Pilih opsi (1/2): " choice

case $choice in
    1)
        install_banner
        ;;
    2)
        uninstall_banner
        ;;
    *)
        echo "Opsi tidak valid!"
        ;;
esac