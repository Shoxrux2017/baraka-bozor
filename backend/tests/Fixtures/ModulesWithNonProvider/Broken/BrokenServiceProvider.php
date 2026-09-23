<?php

declare(strict_types=1);

namespace Tests\Fixtures\ModulesWithNonProvider\Broken;

/**
 * Named like a provider and is not one.
 *
 * Kept in a fixtures root of its own so the well-formed fixtures stay usable:
 * the registry must refuse this, and a test proving that must not also break
 * every other test in the file.
 */
final class BrokenServiceProvider {}
