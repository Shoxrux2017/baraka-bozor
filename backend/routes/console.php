<?php

use Illuminate\Support\Facades\Schedule;

/*
|--------------------------------------------------------------------------
| Scheduled work — docs/07-architecture.md Section 25
|--------------------------------------------------------------------------
|
| Correctness never waits for the scheduler: reads show an overdue approval
| as expired and actions expire their order's first (DL-54 (8)). The command
| writes the rest.
|
*/

Schedule::command('approvals:expire')->everyMinute();

// Daily pruning at 04:00 Tashkent, after the 03:00 backup of W4-3 (DL-104 (8)).
// The devices' pruning arrives with W4-8.
Schedule::command('idempotency-keys:prune')->dailyAt('04:00')->timezone('Asia/Tashkent');
Schedule::command('notification-deliveries:prune')->dailyAt('04:00')->timezone('Asia/Tashkent');
Schedule::command('login-challenges:prune')->dailyAt('04:00')->timezone('Asia/Tashkent');
Schedule::command('queue:prune-failed', ['--hours=720'])->dailyAt('04:00')->timezone('Asia/Tashkent');
