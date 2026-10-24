<?php

declare(strict_types=1);

namespace Tests\Feature\Notifications;

use App\Modules\Notifications\Push\FakePushSender;
use App\Modules\Notifications\Push\FcmPushSender;
use App\Modules\Notifications\Push\PushMessage;
use App\Modules\Notifications\Push\PushSender;
use App\Modules\Notifications\Push\PushSendResult;
use RuntimeException;
use Tests\Support\FcmTestKey;
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

    public function test_the_fcm_driver_binds_the_fcm_sender(): void
    {
        config(['notifications.push_driver' => 'fcm', 'services.fcm.service_account' => FcmTestKey::encoded()]);
        $this->app->forgetInstance(PushSender::class);

        $first = $this->app->make(PushSender::class);
        $second = $this->app->make(PushSender::class);

        $this->assertSame($first, $second);
        $this->assertInstanceOf(FcmPushSender::class, $first);
    }

    public function test_the_fcm_driver_without_a_key_fails_naming_the_setting(): void
    {
        config(['notifications.push_driver' => 'fcm', 'services.fcm.service_account' => null]);
        $this->app->forgetInstance(PushSender::class);

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('FCM_SERVICE_ACCOUNT');

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

    public function test_the_result_constructors_set_the_new_flags(): void
    {
        $rejected = PushSendResult::rejectedToken('UNREGISTERED');
        $this->assertFalse($rejected->sent);
        $this->assertFalse($rejected->retryable);
        $this->assertTrue($rejected->revokesDevice);
        $this->assertSame('UNREGISTERED', $rejected->errorCode);
        $this->assertNull($rejected->retryAfterSeconds);

        $plain = PushSendResult::retry('UNAVAILABLE');
        $this->assertTrue($plain->retryable);
        $this->assertFalse($plain->revokesDevice);
        $this->assertNull($plain->retryAfterSeconds);

        $this->assertSame(300, PushSendResult::retry('QUOTA_EXCEEDED', 300)->retryAfterSeconds);

        foreach ([PushSendResult::sent(), PushSendResult::failed('X')] as $result) {
            $this->assertFalse($result->revokesDevice);
            $this->assertNull($result->retryAfterSeconds);
        }
    }

    public function test_the_testing_binding_answers_sent_by_default(): void
    {
        $result = $this->app->make(PushSender::class)->send('tok', new PushMessage('T', 'B', ['event' => 'x']));

        $this->assertTrue($result->sent);
    }

    public function test_a_fake_that_does_not_report_delivery_answers_failed_fake_driver(): void
    {
        $fake = new FakePushSender(reportsDelivery: false);
        $fake->answerNext(PushSendResult::retry('unavailable'));
        $message = new PushMessage('T', 'B', ['event' => 'x']);

        $queued = $fake->send('tok-1', $message);
        $default = $fake->send('tok-2', $message);

        $this->assertSame('unavailable', $queued->errorCode);
        $this->assertFalse($default->sent);
        $this->assertFalse($default->retryable);
        $this->assertSame('fake_driver', $default->errorCode);
    }
}
