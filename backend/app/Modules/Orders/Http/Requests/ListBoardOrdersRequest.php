<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Requests;

use App\Http\Requests\ListRequest;
use App\Models\Enums\OrderStatus;
use App\Models\Enums\PaymentMethod;
use App\Modules\Orders\Operations\Attention;
use App\Support\Search\TextSearch;
use Carbon\CarbonImmutable;
use Illuminate\Validation\Rule;

/**
 * `GET /operations/orders` (`docs/09` section 38, `DL-37` (16)): the page and
 * the board's filters — a status, the current Shopper, the payment method,
 * the first and last day of placement (`YYYY-MM-DD` in `Asia/Tashkent`), an
 * attention type, and a search of at most 100 characters.
 */
final class ListBoardOrdersRequest extends ListRequest
{
    /**
     * The days a filter may name. Before 1924 `Asia/Tashkent` ran on local
     * mean time, and the first days of the calendar have no UTC instant
     * PostgreSQL takes, so a day outside this range is refused, not queried.
     */
    private const FIRST_DAY = '2000-01-01';

    private const LAST_DAY = '2999-12-31';

    /**
     * @return array<string, mixed>
     */
    protected function filters(): array
    {
        return [
            'status' => ['sometimes', 'nullable', 'string', Rule::enum(OrderStatus::class)],
            'shopper_id' => ['sometimes', 'nullable', 'string', 'uuid'],
            'payment_method' => ['sometimes', 'nullable', 'string', Rule::enum(PaymentMethod::class)],
            'from' => ['sometimes', 'nullable', 'date_format:Y-m-d', 'after_or_equal:'.self::FIRST_DAY, 'before_or_equal:'.self::LAST_DAY],
            'to' => ['sometimes', 'nullable', 'date_format:Y-m-d', 'after_or_equal:'.self::FIRST_DAY, 'before_or_equal:'.self::LAST_DAY, 'after_or_equal:from'],
            'attention' => ['sometimes', 'nullable', 'string', Rule::in(Attention::TYPES)],
            'search' => ['sometimes', 'nullable', 'string', 'max:'.TextSearch::MAX_TERM_LENGTH],
        ];
    }

    public function status(): ?OrderStatus
    {
        $value = $this->text('status');

        return $value === null ? null : OrderStatus::from($value);
    }

    public function shopperId(): ?string
    {
        $value = $this->text('shopper_id');

        return $value === null ? null : strtolower($value);
    }

    public function paymentMethod(): ?PaymentMethod
    {
        $value = $this->text('payment_method');

        return $value === null ? null : PaymentMethod::from($value);
    }

    public function from(): ?CarbonImmutable
    {
        return $this->day('from');
    }

    public function to(): ?CarbonImmutable
    {
        return $this->day('to');
    }

    public function attention(): ?string
    {
        return $this->text('attention');
    }

    public function search(): ?string
    {
        return $this->text('search');
    }

    private function day(string $key): ?CarbonImmutable
    {
        $value = $this->text($key);

        if ($value === null) {
            return null;
        }

        return CarbonImmutable::createFromFormat('!Y-m-d', $value, 'Asia/Tashkent') ?: null;
    }
}
