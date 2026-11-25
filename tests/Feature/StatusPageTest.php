<?php

namespace Tests\Feature;

use Tests\TestCase;

class StatusPageTest extends TestCase
{
    public function test_homepage_displays_application_metadata(): void
    {
        config([
            'app.name' => 'Practice Deployment',
            'app.env' => 'testing',
            'app.version' => '2.3.4',
        ]);

        $this->get('/')
            ->assertOk()
            ->assertSeeTextInOrder(['Practice Deployment', 'Environment', 'testing', 'Version', '2.3.4']);
    }

    public function test_health_endpoint_responds_successfully(): void
    {
        $this->get('/up')->assertOk();
    }
}
