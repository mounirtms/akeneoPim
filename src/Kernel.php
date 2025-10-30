<?php

namespace App;

use Pimcore\Kernel as PimcoreKernel;
use Pimcore\HttpKernel\BundleCollection\BundleCollection;

class Kernel extends PimcoreKernel
{
    /**
     * Adds bundles to the bundle collection. Bundle registration depends on the environment.
     *
     * @param BundleCollection $collection
     */
    public function registerBundlesToCollection(BundleCollection $collection): void
    {
        // Check if AppBundle class exists before adding it
        if (class_exists('\\AppBundle\\AppBundle')) {
            $collection->addBundle(new \AppBundle\AppBundle());
        }
        
        // Register Pimcore Admin UI Classic Bundle (correct class name)
        if (class_exists('\\Pimcore\\Bundle\\AdminBundle\\PimcoreAdminBundle')) {
            $collection->addBundle(new \Pimcore\Bundle\AdminBundle\PimcoreAdminBundle());
        }
    }
}