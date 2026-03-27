<?php

namespace AppBundle\Provider\ContentSecurityPolicy;

use Akeneo\Platform\Bundle\UIBundle\Provider\ContentSecurityPolicy\ContentSecurityPolicyProviderInterface;

class EmptyContentSecurityPolicyProvider implements ContentSecurityPolicyProviderInterface
{
    public function getContentSecurityPolicy(): array
    {
        // Return empty policy to disable CSP
        return [];
    }
}
