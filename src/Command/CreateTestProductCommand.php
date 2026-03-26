<?php

namespace App\Command;

use Pimcore\Model\DataObject\Product;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\Console\Style\SymfonyStyle;

class CreateTestProductCommand extends Command
{
    protected static $defaultName = 'app:create-test-product';
    protected static $defaultDescription = 'Create a test product';

    protected function configure(): void
    {
        $this
            ->setHelp('This command creates a test product in the Pimcore system');
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $io = new SymfonyStyle($input, $output);
        
        try {
            $io->info('Creating test product...');
            
            // Create a new product
            $product = new Product();
            $product->setParentId(1);
            $product->setKey('test-product-' . time());
            $product->setPublished(true);
            $product->setSku('TEST-SKU-' . time());
            $product->setTitle('Test Product', 'en');
            $product->setDescription('This is a test product created via Symfony command', 'en');
            
            $io->info('Saving product...');
            $product->save();
            
            $io->success('Product created successfully with ID: ' . $product->getId());
            return Command::SUCCESS;
            
        } catch (\Exception $e) {
            $io->error('Failed to create product: ' . $e->getMessage());
            return Command::FAILURE;
        }
    }
}