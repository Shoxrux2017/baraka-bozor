<?php

declare(strict_types=1);

namespace Tests\Feature\Http;

use App\Http\Middleware\RequireIdempotencyKey;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * The `Idempotency-Key` header check of `docs/09` Section 48, on a test-only
 * route: missing, not a UUID, and a key the action can read.
 */
final class RequireIdempotencyKeyTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        Route::middleware(['api', RequireIdempotencyKey::class])
            ->post('api/v1/testing/idempotent', fn (Request $request) => response()->json([
                'data' => ['key' => RequireIdempotencyKey::of($request)],
            ]));
    }

    public function test_a_missing_or_blank_key_is_idempotency_key_required(): void
    {
        foreach ([[], [RequireIdempotencyKey::HEADER => ' ']] as $headers) {
            $this->postJson('/api/v1/testing/idempotent', [], $headers)
                ->assertStatus(400)
                ->assertJsonPath('code', 'idempotency_key_required');
        }
    }

    public function test_a_key_that_is_not_a_uuid_is_a_validation_failure_on_the_header(): void
    {
        $this->postJson('/api/v1/testing/idempotent', [], [RequireIdempotencyKey::HEADER => 'retry-1'])
            ->assertStatus(422)
            ->assertJsonPath('code', 'validation_failed')
            ->assertJsonStructure(['errors' => [RequireIdempotencyKey::HEADER]]);
    }

    public function test_a_uuid_passes_and_the_action_reads_it_in_lower_case(): void
    {
        $key = (string) Str::uuid();

        $this->postJson('/api/v1/testing/idempotent', [], [RequireIdempotencyKey::HEADER => strtoupper($key)])
            ->assertOk()
            ->assertJsonPath('data.key', $key);
    }
}
