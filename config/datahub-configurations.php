<?php

return [
    'products' => [
        'general' => [
            'type' => 'graphql',
            'name' => 'products',
            'description' => 'GraphQL endpoint for products',
            'active' => true,
            'group' => 'Products',
        ],
        'schema' => [
            'queryEntities' => [
                'product' => [
                    'class' => 'Product',
                    'name' => 'Product',
                    'columns' => [
                        [
                            'name' => 'sku',
                            'label' => 'SKU',
                            'dataType' => 'input',
                            'attributes' => [],
                        ],
                        [
                            'name' => 'localizedfields',
                            'label' => 'Localized Fields',
                            'dataType' => 'localizedfields',
                            'attributes' => [
                                'title' => [
                                    'name' => 'title',
                                    'label' => 'Title',
                                    'dataType' => 'input',
                                ],
                                'description' => [
                                    'name' => 'description',
                                    'label' => 'Description',
                                    'dataType' => 'wysiwyg',
                                ],
                            ],
                        ],
                        [
                            'name' => 'brand',
                            'label' => 'Brand',
                            'dataType' => 'manyToOneRelation',
                            'attributes' => [],
                        ],
                        [
                            'name' => 'categories',
                            'label' => 'Categories',
                            'dataType' => 'manyToManyObjectRelation',
                            'attributes' => [],
                        ],
                    ],
                ],
            ],
        ],
    ],
];