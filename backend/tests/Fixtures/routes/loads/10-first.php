<?php

use Illuminate\Support\Facades\Route;

Route::get('fixture/first', fn () => response()->json(['module' => 'first']))
    ->name('fixture.first');
