<?php

namespace AppBundle;

use Pimcore\Extension\Bundle\AbstractPimcoreBundle;

class AppBundle extends AbstractPimcoreBundle
{
    public function getNiceName(): string
    {
        return 'App Bundle';
    }

    public function getDescription(): string
    {
        return 'App Bundle';
    }
}
