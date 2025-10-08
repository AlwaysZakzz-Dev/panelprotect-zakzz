#!/bin/bash
# 🧱 AlwaysZakzz Protect Installer
# © 2025 Protect by AlwaysZakzz

echo "========================================"
echo " 🧱  AlwaysZakzz Protect Installer
echo "========================================"
echo
read -p "Masukkan ID Admin Utama (misal: 1): " ADMIN_ID

if ! [[ "$ADMIN_ID" =~ ^[0-9]+$ ]]; then
    echo "❌ ID Admin harus berupa angka!"
    exit 1
fi

echo "✅ Admin utama diset ke ID: $ADMIN_ID"
echo

# Simpan ke .env
if grep -q "MAIN_ADMIN_ID" /var/www/pterodactyl/.env; then
    sed -i "s/^MAIN_ADMIN_ID=.*/MAIN_ADMIN_ID=$ADMIN_ID/" /var/www/pterodactyl/.env
else
    echo "MAIN_ADMIN_ID=$ADMIN_ID" >> /var/www/pterodactyl/.env
fi

# === A. Anti Intip Server ===
fileA="/var/www/pterodactyl/app/Http/Controllers/Api/Client/Server/ServerController.php"
if grep -q "AlwaysZakzz Anti Intip" "$fileA"; then
    echo "✅ A. Anti Intip Server sudah terpasang."
else
    sed -i "/public function index(/a\
\$authUser  = Auth()->user();\
if (\$authUser->id !== $ADMIN_ID && (int)\$server->owner_id !== (int)\$authUser->id) {\
    abort(403, \"AlwaysZakzz Anti Intip Wkwkwk Kalo Mau Intip Server Minimal Server Punya Lu Bukan Punya Orang\");\
}" "$fileA"
    echo "✅ A. Anti Intip Server berhasil ditambahkan."
fi

# === B. Anti Maling SC ===
fileB="/var/www/pterodactyl/app/Http/Controllers/Api/Client/Server/FileController.php"
if grep -q "AlwaysZakzz Anti Intip" "$fileB"; then
    echo "✅ B. Anti Maling SC sudah terpasang."
else
    sed -i "78i\
\$authUser  = Auth()->user();\
if (\$authUser->id !== $ADMIN_ID && (int)\$server->owner_id !== (int)\$authUser->id) {\
    abort(403, \"AlwaysZakzz Anti Intip Wkwkwk Kalo Mau Intip Server Minimal Server Punya Lu Bukan Punya Orang\");\
}" "$fileB"
    echo "✅ B. Anti Maling SC berhasil ditambahkan."
fi

# === C. Anti Ubah Data User ===
fileC="/var/www/pterodactyl/app/Http/Controllers/Admin/UserController.php"
echo "🧱 Mengganti kode Anti Ubah Data User..."
cat <<EOF > "$fileC"
public function update(UserFormRequest \$request, User \$user): RedirectResponse
{
    \$restrictedFields = ['password', 'email', 'first_name', 'last_name'];

    foreach (\$restrictedFields as \$field) {
        if (\$request->filled(\$field) && \$request->user()->id !== $ADMIN_ID) {
            throw new DisplayException("Anti Ubah Data User Aktif! '\$field' hanya bisa diubah oleh user ID $ADMIN_ID ©Protect By AlwaysZakzz");
        }
    }

    \$this->updateService
        ->setUserLevel(User::USER_LEVEL_ADMIN)
        ->handle(\$user, \$request->normalize());

    \$this->alert->success(trans('admin/user.notices.account_updated'))->flash();

    return redirect()->route('admin.users.view', \$user->id);
}

public function json(Request \$request): Model|Collection
{
    \$users = QueryBuilder::for(User::query())->allowedFilters(['email'])->paginate(25);

    if (\$request->query('user_id')) {
        \$user = User::query()->findOrFail(\$request->input('user_id'));
        \$user->md5 = md5(strtolower(\$user->email));
        return \$user;
    }

    return \$users->map(function (\$item) {
        \$item->md5 = md5(strtolower(\$item->email));
        return \$item;
    });
}
EOF
echo "✅ C. Anti Ubah Data User berhasil diganti."

# === D. Anti Intip Location ===
fileD="/var/www/pterodactyl/app/Http/Controllers/Admin/LocationController.php"
echo "🧱 Mengganti kode Anti Intip Location..."
cat <<EOF > "$fileD"
<?php  

namespace Pterodactyl\Http\Controllers\Admin;  

use Illuminate\View\View;  
use Pterodactyl\Models\Location;  
use Illuminate\Http\RedirectResponse;  
use Prologue\Alerts\AlertsMessageBag;  
use Illuminate\View\Factory as ViewFactory;  
use Pterodactyl\Exceptions\DisplayException;  
use Pterodactyl\Http\Controllers\Controller;  
use Pterodactyl\Http\Requests\Admin\LocationFormRequest;  
use Pterodactyl\Services\Locations\LocationUpdateService;  
use Pterodactyl\Services\Locations\LocationCreationService;  
use Pterodactyl\Services\Locations\LocationDeletionService;  
use Pterodactyl\Contracts\Repository\LocationRepositoryInterface;  
use Illuminate\Support\Facades\Auth;  

class LocationController extends Controller  
{  
    public function __construct(  
        protected AlertsMessageBag \$alert,  
        protected LocationCreationService \$creationService,  
        protected LocationDeletionService \$deletionService,  
        protected LocationRepositoryInterface \$repository,  
        protected LocationUpdateService \$updateService,  
        protected ViewFactory \$view  
    ) {}  

    public function index(): View  
    {  
        \$user = Auth::user();  
        if (!\$user || \$user->id !== $ADMIN_ID) {  
            abort(403, "AlwaysZakzz Protect - Akses ditolak");  
        }  

        return \$this->view->make('admin.locations.index', [  
            'locations' => \$this->repository->getAllWithDetails(),  
        ]);  
    }  

    public function view(int \$id): View  
    {  
        \$user = Auth::user();  
        if (!\$user || \$user->id !== $ADMIN_ID) {  
            abort(403, "AlwaysZakzz Protect - Akses ditolak");  
        }  

        return \$this->view->make('admin.locations.view', [  
            'location' => \$this->repository->getWithNodes(\$id),  
        ]);  
    }  

    public function create(LocationFormRequest \$request): RedirectResponse  
    {  
        \$user = Auth::user();  
        if (!\$user || \$user->id !== $ADMIN_ID) {  
            abort(403, "AlwaysZakzz Protect - Akses ditolak");  
        }  

        \$location = \$this->creationService->handle(\$request->normalize());  
        \$this->alert->success('Location was created successfully.')->flash();  

        return redirect()->route('admin.locations.view', \$location->id);  
    }  

    public function update(LocationFormRequest \$request, Location \$location): RedirectResponse  
    {  
        \$user = Auth::user();  
        if (!\$user || \$user->id !== $ADMIN_ID) {  
            abort(403, "AlwaysZakzz Protect - Akses ditolak");  
        }  

        if (\$request->input('action') === 'delete') {  
            return \$this->delete(\$location);  
        }  

        \$this->updateService->handle(\$location->id, \$request->normalize());  
        \$this->alert->success('Location was updated successfully.')->flash();  

        return redirect()->route('admin.locations.view', \$location->id);  
    }  

    public function delete(Location \$location): RedirectResponse  
    {  
        \$user = Auth::user();  
        if (!\$user || \$user->id !== $ADMIN_ID) {  
            abort(403, "AlwaysZakzz Protect - Akses ditolak");  
        }  

        try {  
            \$this->deletionService->handle(\$location->id);  
            return redirect()->route('admin.locations');  
        } catch (DisplayException \$ex) {  
            \$this->alert->danger(\$ex->getMessage())->flash();  
        }  

        return redirect()->route('admin.locations.view', \$location->id);  
    }  
}
EOF
echo "✅ D. Anti Intip Location berhasil diganti."

echo "🧹 Membersihkan cache..."
cd /var/www/pterodactyl || exit
php artisan optimize:clear
echo
echo "✅ Selesai! AlwaysZakzz Protect aktif dengan Admin ID: $ADMIN_ID 🚀"
