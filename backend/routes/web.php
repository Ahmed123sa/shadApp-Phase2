<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Storage;

// Serve stored files — this route catches /storage/* so files in
// storage/app/public are served even under PHP's built-in server
// (which blocks symlinks pointing outside the document root).
Route::get('/storage/{path}', function (string $path) {
    $clean = ltrim($path, '/');
    if (! Storage::disk('public')->exists($clean)) {
        abort(404);
    }
    return Storage::disk('public')->response($clean);
})->where('path', '.*');

Route::get('/', function () {
    return view('welcome');
});
