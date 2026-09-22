<?php

use Illuminate\Support\Facades\Route;

// Same route name as a-module.php. Laravel lets the later registration win
// silently; the loader test asserts this collision is detectable.
Route::get('duplicate/b', fn () => null)->name('fixture.duplicate');
