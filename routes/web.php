<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('status', [
        'name' => config('app.name'),
        'environment' => config('app.env'),
        'version' => config('app.version'),
    ]);
});
