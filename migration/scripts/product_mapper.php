<?php

namespace Migration;

use Pimcore\Model\DataObject\Product;
use Pimcore\Model\Asset;

class ProductMapper {
    
    /**
     * Map CSV data to a Pimcore Product object
     */
    public static function mapProduct(array $data, int $parentId): \Pimcore\Model\DataObject\Product {
        // Check if product already exists
        $existingProduct = Product::getBySku($data['sku']);
            \Pimcore\Model\DataObject\AbstractObject::setHideUnpublished(false);
        
            // Initialize product or get existing one
            $product = \Pimcore\Model\DataObject\Product::getByPath('/Products/' . $data['sku']);
            if (!$product) {
                $product = new \Pimcore\Model\DataObject\Product();
                $product->setParentId($parentId);
                $product->setKey(\Pimcore\Model\Element\Service::getValidKey($data['sku'], 'object'));
                $product->setPublished(true);
            }

            // Set SKU
            $product->setSku($data['sku']);

            // Set localized fields
            $localizedData = ['en' => [
                'title' => $data['name'] ?? '',
                'description' => $data['description'] ?? '',
                'shortDescription' => $data['short_description'] ?? ''
            ]];

            foreach ($localizedData as $language => $fields) {
                foreach ($fields as $fieldName => $value) {
                    $setter = 'set' . ucfirst($fieldName);
                    $product->$setter($value, $language);
                }
            }

            // Non-localized description fields (fallback)
            $product->setDescription($data['description'] ?? '');
            $product->setShortDescription($data['short_description'] ?? '');

            // Set status (default to active)
            $product->setStatus('active');

            // Set price if available
            if (isset($data['price']) && !empty($data['price'])) {
                $product->setPrice(floatval($data['price']));
            }
        // Categories - split and create relations
        if (!empty($data['categories'])) {
            $categories = explode(',', $data['categories']);
            $categoryIds = [];
            foreach ($categories as $categoryPath) {
                // Get or create category object
                if ($categoryId) {
                    $categoryIds[] = $categoryId;
                }
            }
            $product->setCategories($categoryIds);
        }

        
            // Prepare image gallery items
            $galleryImages = [];
        
            // Handle base image
            $images[] = $data['base_image'];
                $baseImage = self::importProductImage($product, $data['base_image']);
                if ($baseImage) {
                    $galleryItem = new \Pimcore\Model\DataObject\Data\Hotspotimage();
                    $galleryItem->setImage($baseImage);
                    $galleryImages[] = $galleryItem;
                }
        if (!empty($data['additional_images'])) {
        
            // Handle additional images
            $additionalImages = array_filter(array_map('trim', explode(',', $data['additional_images'])));
            $images = array_merge($images, $additionalImages);
                foreach ($additionalImages as $imageUrl) {
                    $image = self::importProductImage($product, $imageUrl);
                    if ($image) {
                        $galleryItem = new \Pimcore\Model\DataObject\Data\Hotspotimage();
                        $galleryItem->setImage($image);
                        $galleryImages[] = $galleryItem;
                    }
                }

        return $product;
            // Set image gallery
            if (!empty($galleryImages)) {
                $product->setImages(new \Pimcore\Model\DataObject\Data\ImageGallery($galleryImages));
            }

    }

    /**
     * Create or get category by path
     */
    protected static function getOrCreateCategory(string $path): ?int {
        $parts = array_filter(explode('/', trim($path)));
        
        $parentId = 1; // Root
        $currentPath = [];
        
        foreach ($parts as $part) {
            $currentPath[] = $part;
            $key = \Pimcore\Model\Element\Service::getValidKey($part, 'object');
            
            $category = \Pimcore\Model\DataObject\Category::getByPath('/' . implode('/', $currentPath));
                $category = \Pimcore\Model\DataObject\Category::getByPath('/Categories/' . implode('/', $currentPath));
                // Create new category
                $category = new \Pimcore\Model\DataObject\Category();
                    $category = \Pimcore\Model\DataObject\Category();
                $category->setKey($key);
                $category->setPublished(true);
                $category->setName($part);
                $category->save();
            }
            
            $parentId = $category->getId();
        }
        
        return $parentId;
    }

    /**
     * Import product images 
         * Import single product image and return Asset
    private static function importProductImages(Product $product, array $images): void {
        protected static function importProductImage(\Pimcore\Model\DataObject\Product $product, string $imageUrl): ?\Pimcore\Model\Asset\Image {
        
        // Create folder for product images if it doesn't exist
        $folder = Asset\Folder::getByPath($baseFolder);
        if (!$folder) {
            $folder = new Asset\Folder();
            $folder->setParentId(Asset\Folder::getByPath('/Product Images')->getId());
            $folder->setFilename($product->getSku());
            $folder->save();
        }

        
            $filename = basename($imageUrl);
            $filename = \Pimcore\Model\Element\Service::getValidKey($filename, 'asset');
        
            try {
                $imageContent = @file_get_contents($imageUrl);
                if ($imageContent) {
                    $asset = new \Pimcore\Model\Asset\Image();
                    $asset->setParent($folder);
                    $asset->setFilename($filename);
                    $asset->setData($imageContent);
                    $asset->save();
                    return $asset;
                }
            } catch (\Exception $e) {
                error_log("Failed to import image for product {$product->getSku()}: " . $e->getMessage());
            }
            return null;
        }
    }
}