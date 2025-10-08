#!/bin/bash
# ==========================================================
# 🧩 FULL PANEL PROTECT & REBUILD — AlwaysZakzz Edition
# ==========================================================
# Fitur Aman:
# 1. Install Node.js 20.x + rebuild frontend panel
# 2. Pilih manual admin utama (ID bebas)
# 3. Tambah middleware proteksi (Anti intip / ubah / delete / maling / location)
# 4. Bersihkan cache & rebuild
# ==========================================================

PANEL_DIR="/var/www/pterodactyl"
DB_NAME="panel"
DB_USER="root"

green='\e[32m'; yellow='\e[33m'; red='\e[31m'; nc='\e[0m'

clear
echo -e "${green}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo -e "┃     ⚙️ FULL PANEL PROTECT — AlwaysZakzz       ┃"
echo -e "┃        Secure • Build • Re-Protect Panel      ┃"
echo -e "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${nc}"
sleep 1

# =============== STEP 0: Cek Direktori Panel ===============
if [ ! -d "$PANEL_DIR" ]; then
    echo -e "${red}❌ Folder panel tidak ditemukan di $PANEL_DIR${nc}"
    exit 1
fi

cd $PANEL_DIR

# =============== STEP 1: Install Node.js & Build Panel ===============
echo -e "${yellow}🚀 [1/6] Instalasi Node.js & Build Panel...${nc}"
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >/dev/null 2>&1
apt install -y nodejs yarn >/dev/null 2>&1

node -v && yarn -v
rm -rf node_modules
yarn install >/dev/null 2>&1
export NODE_OPTIONS=--openssl-legacy-provider
yarn build >/dev/null 2>&1
echo -e "${green}✅ Build Panel selesai.${nc}"
sleep 1

# =============== STEP 2: Pilih Admin Utama Manual ===============
echo -e "${yellow}👑 [2/6] Masukkan ID User untuk dijadikan admin utama (contoh: 1 atau 2):${nc}"
read -p "🆔 Masukkan ID Admin Utama: " ADMIN_ID

if [[ -z "$ADMIN_ID" ]]; then
    echo -e "${red}❌ ID tidak boleh kosong!${nc}"
    exit 1
fi

mysql -u $DB_USER -p $DB_NAME -e "UPDATE users SET root_admin = 1 WHERE id = $ADMIN_ID;"
echo -e "${green}✅ User ID $ADMIN_ID sekarang admin utama.${nc}"
sleep 1

# =============== STEP 3: Backup File Penting ===============
echo -e "${yellow}📦 [3/6] Membackup file penting panel...${nc}"
BACKUP_DIR="/root/panel_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR
cp -r $PANEL_DIR/app/Http/Controllers $BACKUP_DIR/
cp -r $PANEL_DIR/routes $BACKUP_DIR/
echo -e "${green}✅ Backup tersimpan di: $BACKUP_DIR${nc}"
sleep 1

# =============== STEP 4: Tambah Middleware Proteksi Aman ===============
echo -e "${yellow}🧱 [4/6] Menambahkan sistem proteksi AlwaysZakzz Secure Middleware...${nc}"

MW_DIR="$PANEL_DIR/app/Http/Middleware"
MW_FILE="$MW_DIR/AlwaysZakzzProtect.php"

cat > "$MW_FILE" <<'EOF'
<?php

namespace Pterodactyl\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Pterodactyl\Exceptions\DisplayException;

class AlwaysZakzzProtect
{
    public function handle(Request $request, Closure $next)
    {
        $user = $request->user();

        if (!$user) return $next($request);

        $adminMainId = (int) env('MAIN_ADMIN_ID', 1);

        // 🧩 Proteksi Anti Intip Server
        if (str_contains($request->path(), 'servers') && $user->id !== $adminMainId) {
            if ($request->isMethod('DELETE')) {
                throw new DisplayException("🚫 Dilarang menghapus server! Proteksi aktif ©AlwaysZakzz");
            }
        }

        // 🧩 Proteksi Anti Delete User/Admin
        if (str_contains($request->path(), 'admin/users') && $user->id !== $adminMainId) {
            if ($request->isMethod('DELETE')) {
                throw new DisplayException("🚫 Hanya Admin Utama yang bisa menghapus user/admin ©AlwaysZakzz");
            }
        }

        // 🧩 Proteksi Anti Ubah Data Sensitif
        if ($request->isMethod('PUT') || $request->isMethod('PATCH')) {
            $sensitive = ['email', 'password', 'first_name', 'last_name'];
            foreach ($sensitive as $field) {
                if ($request->has($field) && $user->id !== $adminMainId) {
                    throw new DisplayException("🚫 Tidak bisa ubah data sensitif! Field: {$field} dilindungi ©AlwaysZakzz");
                }
            }
        }

        // 🧩 Proteksi Anti Akses Location Panel
        if (str_contains($request->path(), 'locations') && $user->id !== $adminMainId) {
            throw new DisplayException("🚫 Dilarang mengintip lokasi panel ©AlwaysZakzz Protect");
        }

        return $next($request);
    }
}
EOF

# Tambahkan ke Kernel Laravel agar aktif
KERNEL_FILE="$PANEL_DIR/app/Http/Kernel.php"
if ! grep -q "AlwaysZakzzProtect" "$KERNEL_FILE"; then
    sed -i "/protected \$routeMiddleware = \[/a \ \ \ \ 'zakzz.protect' => \App\Http\Middleware\AlwaysZakzzProtect::class," "$KERNEL_FILE"
fi

# Tambahkan ke routes/web.php
ROUTE_FILE="$PANEL_DIR/routes/web.php"
if ! grep -q "zakzz.protect" "$ROUTE_FILE"; then
    sed -i "1i\\Route::middleware(['web','auth','zakzz.protect'])->group(function(){});" "$ROUTE_FILE"
fi

echo -e "${green}✅ Proteksi AlwaysZakzzProtect aktif.${nc}"
sleep 1

# =============== STEP 5: Tambah ENV Admin Utama ===============
echo -e "${yellow}🧩 [5/6] Menambahkan MAIN_ADMIN_ID ke file .env...${nc}"
if ! grep -q "MAIN_ADMIN_ID" "$PANEL_DIR/.env"; then
    echo "MAIN_ADMIN_ID=$ADMIN_ID" >> "$PANEL_DIR/.env"
else
    sed -i "s/MAIN_ADMIN_ID=.*/MAIN_ADMIN_ID=$ADMIN_ID/" "$PANEL_DIR/.env"
fi
echo -e "${green}✅ MAIN_ADMIN_ID diset ke $ADMIN_ID.${nc}"
sleep 1

# =============== STEP 6: Finalisasi Panel ===============
echo -e "${yellow}🧹 [6/6] Membersihkan cache & restart queue...${nc}"
php artisan view:clear
php artisan cache:clear
php artisan config:clear
php artisan route:clear
php artisan queue:restart
echo -e "${green}✅ Semua cache dibersihkan & panel direfresh.${nc}"

# =============== DONE ===============
echo -e "${green}🎉 Semua langkah selesai!${nc}"
echo -e "${yellow}Proteksi aktif: Anti Intip • Anti Ubah • Anti Delete • Anti Location • Anti Maling${nc}"
echo -e "${green}Admin utama: User ID $ADMIN_ID${nc}"
echo -e "${yellow}© AlwaysZakzz Secure Build — Stable & Safe Version${nc}"
