<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Category;
use App\Models\Enums\Role;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * Builds categories the database will accept: both names present, an Admin as
 * the creator (created on demand, so a test that does not care about the
 * Admin never has to make one).
 *
 * @extends Factory<Category>
 */
final class CategoryFactory extends Factory
{
    protected $model = Category::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'name_uz' => 'Sabzavotlar '.fake()->unique()->numberBetween(1, 100000),
            'name_ru' => 'Овощи '.fake()->numberBetween(1, 100000),
            'description_uz' => null,
            'description_ru' => null,
            'sort_order' => 0,
            'is_active' => true,
            'archived_at' => null,
            'created_by_user_id' => User::factory()->role(Role::Admin),
        ];
    }

    /**
     * An archived category, with the two columns the check keeps together.
     */
    public function archived(): self
    {
        return $this->state(fn (): array => [
            'is_active' => false,
            'archived_at' => now(),
        ]);
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function newModel(array $attributes = []): Category
    {
        return (new Category)->forceFill($attributes);
    }
}
