<?php

return [
    // Symfony Core
    Symfony\Bundle\FrameworkBundle\FrameworkBundle::class => ['all' => true],
    Symfony\Bundle\TwigBundle\TwigBundle::class => ['all' => true],
    Symfony\Bundle\SecurityBundle\SecurityBundle::class => ['all' => true],
    Symfony\Bundle\MonologBundle\MonologBundle::class => ['all' => true],
    Symfony\Bundle\WebProfilerBundle\WebProfilerBundle::class => ['dev' => true],
    Symfony\Bundle\DebugBundle\DebugBundle::class => ['dev' => true],
    
    // Doctrine
    Doctrine\Bundle\DoctrineBundle\DoctrineBundle::class => ['all' => true],
    Doctrine\Bundle\MigrationsBundle\DoctrineMigrationsBundle::class => ['all' => true],
    
    // FOSJsRouting
    FOS\JsRoutingBundle\FOSJsRoutingBundle::class => ['all' => true],
    
    // Pimcore Core (MUST BE LAST)
    Pimcore\Bundle\SimpleBackendSearchBundle\PimcoreSimpleBackendSearchBundle::class => ['all' => true],
    Pimcore\Bundle\SeoBundle\PimcoreSeoBundle::class => ['all' => true],
    Pimcore\Bundle\TinymceBundle\PimcoreTinymceBundle::class => ['all' => true],
    Pimcore\Bundle\UuidBundle\PimcoreUuidBundle::class => ['all' => true],
    Pimcore\Bundle\ApplicationLoggerBundle\PimcoreApplicationLoggerBundle::class => ['all' => true],
    Pimcore\Bundle\CustomReportsBundle\PimcoreCustomReportsBundle::class => ['all' => true],
    Pimcore\Bundle\GlossaryBundle\PimcoreGlossaryBundle::class => ['all' => true],
    Pimcore\Bundle\StaticRoutesBundle\PimcoreStaticRoutesBundle::class => ['all' => true],
    Pimcore\Bundle\DataHubBundle\PimcoreDataHubBundle::class => ['all' => true],
    Pimcore\Bundle\DataImporterBundle\PimcoreDataImporterBundle::class => ['all' => true],
    Pimcore\Bundle\AdminBundle\PimcoreAdminBundle::class => ['all' => true],
    Pimcore\Bundle\CoreBundle\PimcoreCoreBundle::class => ['all' => true],
];
