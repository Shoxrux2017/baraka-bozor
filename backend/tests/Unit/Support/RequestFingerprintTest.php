<?php

declare(strict_types=1);

namespace Tests\Unit\Support;

use App\Support\Idempotency\RequestFingerprint;
use InvalidArgumentException;
use PHPUnit\Framework\TestCase;
use stdClass;

/**
 * `DL-37` (5): the request hash is over the operation, the route parameters
 * and the body, canonically.
 */
final class RequestFingerprintTest extends TestCase
{
    public function test_it_is_a_lower_case_sha256_hex_digest(): void
    {
        $this->assertMatchesRegularExpression('/^[0-9a-f]{64}$/', RequestFingerprint::of('orders.create', [], []));
    }

    public function test_the_order_object_keys_were_written_in_does_not_matter_at_any_depth(): void
    {
        $this->assertSame(
            RequestFingerprint::of('orders.edit', ['order' => 'a'], ['items' => [['quantity' => '2', 'product_id' => 'p']], 'delivery_time_note' => 'после 18:00']),
            RequestFingerprint::of('orders.edit', ['order' => 'a'], ['delivery_time_note' => 'после 18:00', 'items' => [['product_id' => 'p', 'quantity' => '2']]])
        );
    }

    public function test_a_lists_order_matters(): void
    {
        $this->assertNotSame(
            RequestFingerprint::of('orders.edit', [], ['items' => [['product_id' => 'a'], ['product_id' => 'b']]]),
            RequestFingerprint::of('orders.edit', [], ['items' => [['product_id' => 'b'], ['product_id' => 'a']]])
        );
    }

    public function test_the_operation_the_route_and_the_body_each_change_it(): void
    {
        $base = RequestFingerprint::of('orders.cancel', ['order' => 'a'], []);

        $this->assertNotSame($base, RequestFingerprint::of('orders.cancel', ['order' => 'b'], []), 'One key on two orders is a key reused.');
        $this->assertNotSame($base, RequestFingerprint::of('orders.create', ['order' => 'a'], []));
        $this->assertNotSame($base, RequestFingerprint::of('orders.cancel', ['order' => 'a'], ['reason' => 'x']));
    }

    public function test_numbers_and_strings_keep_their_json_form(): void
    {
        $this->assertNotSame(RequestFingerprint::of('x', [], ['n' => 5]), RequestFingerprint::of('x', [], ['n' => '5']));
        $this->assertNotSame(RequestFingerprint::of('x', [], ['n' => 5]), RequestFingerprint::of('x', [], ['n' => 5.0]));
    }

    public function test_a_route_id_in_either_case_is_one_request(): void
    {
        $this->assertSame(
            RequestFingerprint::of('orders.cancel', ['order' => '01A0E358-DF27-7124-8013-3B4EFF896D9D'], []),
            RequestFingerprint::of('orders.cancel', ['order' => '01a0e358-df27-7124-8013-3b4eff896d9d'], [])
        );
    }

    public function test_an_object_leaf_is_refused(): void
    {
        $this->expectException(InvalidArgumentException::class);

        RequestFingerprint::of('x', [], ['model' => new stdClass]);
    }

    public function test_a_decimal_string_is_not_its_number(): void
    {
        $this->assertNotSame(
            RequestFingerprint::of('cart.add', [], ['quantity' => '5.000']),
            RequestFingerprint::of('cart.add', [], ['quantity' => '5'])
        );
    }
}
