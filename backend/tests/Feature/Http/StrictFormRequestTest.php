<?php

declare(strict_types=1);

namespace Tests\Feature\Http;

use App\Http\Requests\StrictFormRequest;
use Illuminate\Support\Facades\Route;
use Tests\TestCase;

/**
 * `StrictFormRequest` refuses undeclared fields at every depth — docs/09
 * Section 4 — and leaves the query string out of a mutation's shape.
 */
final class StrictFormRequestTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        Route::middleware('api')->prefix('api/v1/testing')->group(function (): void {
            Route::post('strict', fn (NestedTestRequest $request) => response()->json(['data' => $request->validated()]));
        });
    }

    public function test_a_declared_nested_shape_is_accepted(): void
    {
        $this->postJson('/api/v1/testing/strict', [
            'note' => 'x',
            'items' => [
                ['product_id' => 'p1', 'quantity' => '2', 'options' => ['anything' => ['goes' => true]]],
            ],
        ])->assertOk();
    }

    public function test_an_undeclared_nested_field_is_refused_with_its_full_path(): void
    {
        $response = $this->postJson('/api/v1/testing/strict', [
            'note' => 'x',
            'items' => [
                ['product_id' => 'p1', 'quantity' => '2'],
                ['product_id' => 'p2', 'quantity' => '1', 'price_uzs' => 100],
            ],
        ]);

        $response->assertStatus(422)
            ->assertJsonPath('code', 'validation_failed')
            ->assertJsonValidationErrors(['items.1.price_uzs']);
    }

    public function test_an_undeclared_top_level_field_is_refused_even_when_the_rest_fails_too(): void
    {
        $this->postJson('/api/v1/testing/strict', ['role' => 'admin'])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['role', 'note']);
    }

    public function test_the_query_string_is_not_part_of_the_shape(): void
    {
        $this->postJson('/api/v1/testing/strict?debug=1', ['note' => 'x'])->assertOk();
    }
}

final class NestedTestRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'note' => ['required', 'string'],
            'items' => ['sometimes', 'array'],
            'items.*.product_id' => ['required', 'string'],
            'items.*.quantity' => ['required', 'string'],
            'items.*.options' => ['sometimes', 'array'],
        ];
    }
}
