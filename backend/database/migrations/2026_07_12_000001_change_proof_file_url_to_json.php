<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement('ALTER TABLE payments ALTER COLUMN proof_file_url TYPE json USING to_json(proof_file_url)');
    }

    public function down(): void
    {
        DB::statement('ALTER TABLE payments ALTER COLUMN proof_file_url TYPE varchar(255) USING proof_file_url::text');
    }
};
