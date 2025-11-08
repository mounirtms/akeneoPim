<?php

namespace App;

use Pimcore\Kernel as PimcoreKernel;
use Pimcore\HttpKernel\BundleCollection\BundleCollection;

class MinimalAppKernel extends PimcoreKernel
{
    public function registerBundlesToCollection(BundleCollection $collection): void
    {
        // Only register core Pimcore bundles
        if (class_exists('\\Pimcore\\Bundle\\AdminClassicBundle\\PimcoreAdminClassicBundle')) {
            $collection->addBundle(new \Pimcore\Bundle\AdminClassicBundle\PimcoreAdminClassicBundle());
        }
    }
}