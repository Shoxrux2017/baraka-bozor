<?php

use Illuminate\Support\Facades\Route;

// Same route name as a-module.php. Laravel keeps the FIRST registration - see
// RouteCollection::addLookups - so without the loader's guard this route would
// be unreachable by name while route("fixture.duplicate") resolved to a-module.
Route::get('duplicate/b', fn () => null)->name('fixture.duplicate');
