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
