<?php

namespace App\Command;

use Pimcore\Console\AbstractCommand;
use Pimcore\Model\DataObject\Product;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\Console\Style\SymfonyStyle;

class CreateProductCommand extends AbstractCommand
{
    protected function configure()
    {
        $this
            ->setName('app:create-product')
            ->setDescription('Create a test product');
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $io = new SymfonyStyle($input, $output);
        
        try {
            $io->info('Creating product...');
            
            $product = new Product();
            $product->setParentId(1); // Root folder
            $product->setKey('test-product-' . time());
            $product->setPublished(true);
            $product->setSku('TEST-SKU-' . time());
            $product->setTitle('Test Product', 'en');
            $product->setDescription('This is a test product', 'en');
            
            $product->save();
            
            $io->success('Product created successfully with ID: ' . $product->getId());
            return 0;
        } catch (\Exception $e) {
            $io->error('Error creating product: ' . $e->getMessage());
            $io->writeln($e->getTraceAsString());
            return 1;
        }
    }
}