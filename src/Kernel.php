<?php

namespace App;

use Pimcore\Kernel as PimcoreKernel;
use Pimcore\HttpKernel\BundleCollection\BundleCollection;
use Pimcore\Bundle\AdminBundle\PimcoreAdminBundle;

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
        
        // Register Pimcore Admin UI Bundle
        $collection->addBundle(new PimcoreAdminBundle());
        
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
        
        // Register Dachcom Toolbox bundle (content areas, themes, etc.)
        if (class_exists('\\ToolboxBundle\\ToolboxBundle')) {
            $collection->addBundle(new \ToolboxBundle\ToolboxBundle());
        }

        // Register Dachcom SEO bundle (meta data, indexing)
        if (class_exists('\\SeoBundle\\SeoBundle')) {
            $collection->addBundle(new \SeoBundle\SeoBundle());
        }

        // Register Application Logger Bundle for enhanced logging
        if (class_exists('\\Pimcore\\Bundle\\ApplicationLoggerBundle\\PimcoreApplicationLoggerBundle')) {
            $collection->addBundle(new \Pimcore\Bundle\ApplicationLoggerBundle\PimcoreApplicationLoggerBundle());
        }
    }
}