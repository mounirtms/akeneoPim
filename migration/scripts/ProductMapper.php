<?php

namespace Migration;

use Pimcore\Model\DataObject\Product;
use Pimcore\Model\DataObject\AbstractObject;
use Pimcore\Model\DataObject\Category;
use Pimcore\Model\Asset;
use Pimcore\Model\Asset\Image;
use Pimcore\Model\DataObject\Data\Hotspotimage;
use Pimcore\Model\DataObject\Data\ImageGallery;
use Pimcore\Model\Element\Service;

class ProductMapper {
    /**
     * Map CSV data to a Pimcore Product object
     */
    public static function mapProduct(array $data, int $parentId): Product {
        AbstractObject::setHideUnpublished(false);
        
        // Initialize product or get existing one
        $product = Product::getByPath('/Products/' . $data['sku']);
        if (!$product) {
            $product = new Product();
            $product->setParentId($parentId);
            $product->setKey(Service::getValidKey($data['sku'], 'object'));
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
                $categoryId = self::getOrCreateCategory($categoryPath);
                if ($categoryId) {
                    $categoryIds[] = $categoryId;
                }
            }
            $product->setCategories($categoryIds);
        }
        
        // Prepare image gallery items
        $galleryImages = [];
        
        // Handle base image
        if (!empty($data['base_image'])) {
            $baseImage = self::importProductImage($product, $data['base_image']);
            if ($baseImage) {
                $galleryItem = new Hotspotimage();
                $galleryItem->setImage($baseImage);
                $galleryImages[] = $galleryItem;
            }
        }
        
        // Handle additional images
        if (!empty($data['additional_images'])) {
            $additionalImages = array_filter(array_map('trim', explode(',', $data['additional_images'])));
            foreach ($additionalImages as $imageUrl) {
                $image = self::importProductImage($product, $imageUrl);
                if ($image) {
                    $galleryItem = new Hotspotimage();
                    $galleryItem->setImage($image);
                    $galleryImages[] = $galleryItem;
                }
            }
        }

        // Set image gallery
        if (!empty($galleryImages)) {
            $product->setImages(new ImageGallery($galleryImages));
        }

        return $product;
    }

    /**
     * Create or get category by path
     */
    public static function getOrCreateCategory(string $path): ?int {
        $parts = array_filter(explode('/', trim($path)));
        
        $parentId = 1; // Root
        $currentPath = [];
        
        foreach ($parts as $part) {
            $currentPath[] = $part;
            $key = Service::getValidKey($part, 'object');
            
            $category = Category::getByPath('/Categories/' . implode('/', $currentPath));
            if (!$category) {
                // Create new category
                $category = new Category();
                $category->setParentId($parentId);
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
     * Import single product image and return Asset
     */
    public static function importProductImage(Product $product, string $imageUrl): ?Image {
        $baseFolder = '/Product Images/' . $product->getSku();
        
        // Create folder for product images if it doesn't exist
        $folder = Asset\Folder::getByPath($baseFolder);
        if (!$folder) {
            $folder = new Asset\Folder();
            $folder->setParentId(Asset\Folder::getByPath('/Product Images')->getId());
            $folder->setFilename($product->getSku());
            $folder->save();
        }
        
        $filename = basename($imageUrl);
        $filename = Service::getValidKey($filename, 'asset');
        
        try {
            $imageContent = @file_get_contents($imageUrl);
            if ($imageContent) {
                $asset = new Image();
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