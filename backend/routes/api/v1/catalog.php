<?php

declare(strict_types=1);

use App\Models\Enums\Role;
use App\Modules\Auth\AuthServiceProvider;
use App\Modules\Auth\Http\Middleware\RequireRole;
use App\Modules\Catalog\Http\Controllers\AdminCategoryController;
use App\Modules\Catalog\Http\Controllers\AdminProductController;
use App\Modules\Catalog\Http\Controllers\AdminProductImageController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Catalog — docs/09-api-contracts.md Sections 14 to 16
|--------------------------------------------------------------------------
|
| The Admin catalog is Admin only: the Operator surface hides the catalog
| (docs/02 Section 7). The Customer catalog arrives with W1-5.
|
*/

Route::middleware([AuthServiceProvider::PROTECTED, RequireRole::of(Role::Admin)])
    ->prefix('admin')
    ->group(function (): void {
        Route::get('categories', [AdminCategoryController::class, 'index'])->name('admin.categories.index');
        Route::post('categories', [AdminCategoryController::class, 'store'])->name('admin.categories.store');
        Route::get('categories/{category}', [AdminCategoryController::class, 'show'])->name('admin.categories.show');
        Route::patch('categories/{category}', [AdminCategoryController::class, 'update'])->name('admin.categories.update');
        Route::post('categories/{category}/archive', [AdminCategoryController::class, 'archive'])->name('admin.categories.archive');
        Route::post('categories/{category}/restore', [AdminCategoryController::class, 'restore'])->name('admin.categories.restore');

        Route::get('products', [AdminProductController::class, 'index'])->name('admin.products.index');
        Route::post('products', [AdminProductController::class, 'store'])->name('admin.products.store');
        Route::get('products/{product}', [AdminProductController::class, 'show'])->name('admin.products.show');
        Route::patch('products/{product}', [AdminProductController::class, 'update'])->name('admin.products.update');
        Route::post('products/{product}/archive', [AdminProductController::class, 'archive'])->name('admin.products.archive');
        Route::post('products/{product}/restore', [AdminProductController::class, 'restore'])->name('admin.products.restore');

        Route::post('products/{product}/image', [AdminProductImageController::class, 'store'])->name('admin.products.image.store');
        Route::delete('products/{product}/image', [AdminProductImageController::class, 'destroy'])->name('admin.products.image.destroy');
    });
