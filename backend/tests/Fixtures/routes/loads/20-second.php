<?php

use Illuminate\Support\Facades\Route;

// Deliberately named so that sorted order puts it after 10-first.php.
Route::get('fixture/second', fn () => response()->json(['module' => 'second']))
    ->name('fixture.second');
