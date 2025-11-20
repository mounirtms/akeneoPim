<?php

use Pimcore\Model\Asset\Image\Thumbnail\Config;

return [
    'content' => [
        'thumbnails' => [
            [
                'name' => 'product-detail',
                'description' => 'Product detail image',
                'format' => 'JPEG',
                'quality' => 85,
                'items' => [
                    [
                        'method' => 'scaleByWidth',
                        'arguments' => [
                            'width' => 800,
                            'forceResize' => false,
                        ],
                    ],
                ],
            ],
            [
                'name' => 'product-list',
                'description' => 'Product list thumbnail',
                'format' => 'JPEG',
                'quality' => 80,
                'items' => [
                    [
                        'method' => 'cover',
                        'arguments' => [
                            'width' => 300,
                            'height' => 300,
                            'positioning' => 'center',
                            'forceResize' => false,
                        ],
                    ],
                ],
            ],
            [
                'name' => 'product-gallery',
                'description' => 'Product gallery thumbnail',
                'format' => 'JPEG',
                'quality' => 85,
                'items' => [
                    [
                        'method' => 'scaleByWidth',
                        'arguments' => [
                            'width' => 1200,
                            'forceResize' => false,
                        ],
                    ],
                ],
            ],
            [
                'name' => 'category-image',
                'description' => 'Category image',
                'format' => 'JPEG',
                'quality' => 80,
                'items' => [
                    [
                        'method' => 'contain',
                        'arguments' => [
                            'width' => 600,
                            'height' => 400,
                            'forceResize' => false,
                        ],
                    ],
                ],
            ],
            [
                'name' => 'brand-logo',
                'description' => 'Brand logo',
                'format' => 'PNG',
                'quality' => 90,
                'items' => [
                    [
                        'method' => 'scaleByWidth',
                        'arguments' => [
                            'width' => 200,
                            'forceResize' => false,
                        ],
                    ],
                ],
            ],
        ],
    ],
];