#!/bin/bash
# =========================================================
# 🛡️ PANEL PROTECT — ZAKZZ EDITION
# Versi aman & transparan — proteksi dasar Pterodactyl Panel
# =========================================================

set -e

PANEL_DIR="/var/www/pterodactyl"
ADMIN_ID=1
DATE=$(date +"%Y%m%d_%H%M%S")

echo "=== PanelProtect Zakzz Started ==="
echo "📁 Panel path  : $PANEL_DIR"
echo "👤 Admin ID    : $ADMIN_ID"
echo "🕒 Timestamp   : $DATE"
echo "=================================="

# --- Cek direktori panel ---
if [ ! -d "$PANEL_DIR" ]; then
  echo "❌ Folder panel tidak ditemukan di: $PANEL_DIR"
  echo "Silakan ubah variabel PANEL_DIR di script ini."
  exit 1
fi

# --- Backup file penting ---
mkdir -p "$PANEL_DIR/backups"
echo "📦 Membuat backup file penting..."
cp "$PANEL_DIR/app/Http/Controllers/Admin/UserController.php" "$PANEL_DIR/backups/UserController.php.bak_$DATE" || true
cp "$PANEL_DIR/app/Services/Servers/ServerDeletionService.php" "$PANEL_DIR/backups/ServerDeletionService.php.bak_$DATE" || true
echo "✅ Backup selesai di folder: $PANEL_DIR/backups"

# --- Proteksi UserController (hapus/edit user) ---
USER_CTRL="$PANEL_DIR/app/Http/Controllers/Admin/UserController.php"
if grep -q "function delete" "$USER_CTRL"; then
  echo "🔒 Menambahkan proteksi pada UserController..."
  sed -i "/function delete/i \        \$user = auth()->user(); if(!\$user || \$user->id != $ADMIN_ID){ throw new \\\Pterodactyl\\Exceptions\\DisplayException('Akses ditolak: hanya admin utama.'); }" "$USER_CTRL"
  echo "✅ Proteksi berhasil diterapkan pada UserController.php"
else
  echo "⚠️ Tidak ditemukan function delete pada UserController.php"
fi

# --- Proteksi ServerDeletionService (hapus server) ---
SRV_SERVICE="$PANEL_DIR/app/Services/Servers/ServerDeletionService.php"
if grep -q "function handle" "$SRV_SERVICE"; then
  echo "🔒 Menambahkan proteksi pada ServerDeletionService..."
  sed -i "/function handle/i \        \$user = auth()->user(); if(!\$user || \$user->id != $ADMIN_ID){ throw new \\\Pterodactyl\\Exceptions\\DisplayException('Akses ditolak: hanya admin utama.'); }" "$SRV_SERVICE"
  echo "✅ Proteksi berhasil diterapkan pada ServerDeletionService.php"
else
  echo "⚠️ Tidak ditemukan function handle pada ServerDeletionService.php"
fi

# --- Opsi build frontend ---
read -p "🔧 Mau rebuild frontend panel sekarang? (y/n): " rebuild
if [[ "$rebuild" =~ ^[Yy]$ ]]; then
  echo "⚙️  Menjalankan build panel..."
  cd $PANEL_DIR
  export NODE_OPTIONS=--openssl-legacy-provider
  yarn install
  yarn build:production
  echo "✅ Build selesai!"
else
  echo "⏩ Lewati build panel."
fi

echo "=================================="
echo "✅ Proteksi Panel selesai!"
echo "Backup tersimpan di: $PANEL_DIR/backups/"
echo "Dibuat oleh: Zakzz Security — $(date)"
echo "=================================="
