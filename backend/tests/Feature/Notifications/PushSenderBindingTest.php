<?php

declare(strict_types=1);

namespace Tests\Feature\Notifications;

use App\Modules\Notifications\Push\FakePushSender;
use App\Modules\Notifications\Push\PushMessage;
use App\Modules\Notifications\Push\PushSender;
use App\Modules\Notifications\Push\PushSendResult;
use RuntimeException;
use Tests\TestCase;

final class PushSenderBindingTest extends TestCase
{
    public function test_the_fake_is_bound_by_default(): void
    {
        $first = $this->app->make(PushSender::class);
        $second = $this->app->make(PushSender::class);

        $this->assertInstanceOf(FakePushSender::class, $first);
        $this->assertSame($first, $second);
    }

    public function test_an_unknown_driver_fails_naming_the_setting(): void
    {
        config(['notifications.push_driver' => 'pigeon']);
        $this->app->forgetInstance(PushSender::class);

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('PUSH_DRIVER');

        $this->app->make(PushSender::class);
    }

    public function test_the_fake_answers_queued_results_then_sent(): void
    {
        $fake = $this->app->make(FakePushSender::class);
        $fake->answerNext(PushSendResult::retry('unavailable'), PushSendResult::failed('invalid_token'));
        $message = new PushMessage('T', 'B', ['event' => 'order_accepted', 'order_id' => 'x']);

        $first = $fake->send('tok-1', $message);
        $second = $fake->send('tok-2', $message);
        $third = $fake->send('tok-3', $message);

        $this->assertFalse($first->sent);
        $this->assertTrue($first->retryable);
        $this->assertSame('unavailable', $first->errorCode);
        $this->assertFalse($second->sent);
        $this->assertFalse($second->retryable);
        $this->assertSame('invalid_token', $second->errorCode);
        $this->assertTrue($third->sent);
        $this->assertNull($third->errorCode);
        $this->assertCount(3, $fake->sent());
        $this->assertSame('tok-3', $fake->sent()[2]['token']);
    }
}
