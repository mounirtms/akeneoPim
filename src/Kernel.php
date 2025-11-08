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
        
        // Register Pimcore Admin UI Classic Bundle (correct class name for Pimcore 11)
        if (class_exists('\\Pimcore\\Bundle\\AdminClassicBundle\\PimcoreAdminClassicBundle')) {
            $collection->addBundle(new \Pimcore\Bundle\AdminClassicBundle\PimcoreAdminClassicBundle());
        }
        
        // Register FOSJsRoutingBundle for JavaScript routing
        if (class_exists('\\FOS\\JsRoutingBundle\\FOSJsRoutingBundle')) {
            $collection->addBundle(new \FOS\JsRoutingBundle\FOSJsRoutingBundle());
        }
        
        // Register additional bundles for enhanced dashboard experience
        if (class_exists('\\Pimcore\\Bundle\\SimpleBackendSearchBundle\\PimcoreSimpleBackendSearchBundle')) {
            $collection->addBundle(new \Pimcore\Bundle\SimpleBackendSearchBundle\PimcoreSimpleBackendSearchBundle());
        }
        
        if (class_exists('\\Pimcore\\Bundle\\CustomReportsBundle\\PimcoreCustomReportsBundle')) {
            $collection->addBundle(new \Pimcore\Bundle\CustomReportsBundle\PimcoreCustomReportsBundle());
        }
        
        // Register DataHub Bundle
        if (class_exists('\\Pimcore\\Bundle\\DataHubBundle\\PimcoreDataHubBundle')) {
            $collection->addBundle(new \Pimcore\Bundle\DataHubBundle\PimcoreDataHubBundle());
        }
        
        // Register DataImporter Bundle
        if (class_exists('\\Pimcore\\Bundle\\DataImporterBundle\\PimcoreDataImporterBundle')) {
            $collection->addBundle(new \Pimcore\Bundle\DataImporterBundle\PimcoreDataImporterBundle());
        }
        
        // Register Message Bundle for notifications
        if (class_exists('\\LemonMind\\MessageBundle\\LemonmindMessageBundle')) {
            $collection->addBundle(new \LemonMind\MessageBundle\LemonmindMessageBundle());
        }
        
        // Register Process Manager Bundle
        if (class_exists('\\Elements\Bundle\ProcessManagerBundle\ElementsProcessManagerBundle')) {
            $collection->addBundle(new \Elements\Bundle\ProcessManagerBundle\ElementsProcessManagerBundle());
        }
    }
}