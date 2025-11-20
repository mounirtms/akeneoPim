<?php

namespace AppBundle\Model\DataObject;

use Pimcore\Model\DataObject\ClassDefinition;

class ProductClass
{
    public static function create()
    {
        // Check if class already exists
        $class = ClassDefinition::getByName('Product');
        if (!$class) {
            $class = new ClassDefinition();
        }
        $class->setName("Product");
        $class->setDescription("Product master data");
        
        // Base product fields
        $panel = new ClassDefinition\Layout\Panel();
        $panel->setName("Base");
        
        // SKU field
        $sku = new ClassDefinition\Data\Input();
        $sku->setName("sku");
        $sku->setTitle("SKU");
        $sku->setMandatory(true);
        $sku->setIndex(true);
        $sku->setUnique(true);
        $panel->addChild($sku);
        
        // Localized fields container
        $localizedFields = new ClassDefinition\Data\Localizedfields();
        $localizedFields->setName("localizedfields");
        $localizedFields->setTitle("Localized Fields");
        
        // Title field (localized)
        $title = new ClassDefinition\Data\Input();
        $title->setName("title");
        $title->setTitle("Product Title");
        $title->setMandatory(true);
        $localizedFields->addChild($title);
        
        // Description (localized wysiwyg)
        $description = new ClassDefinition\Data\Wysiwyg();
        $description->setName("description");
        $description->setTitle("Description");
        $description->setHeight(300);
        $localizedFields->addChild($description);
        
        // Short Description
        $shortDescription = new ClassDefinition\Data\Textarea();
        $shortDescription->setName("shortDescription");
        $shortDescription->setTitle("Short Description");
        $shortDescription->setHeight(100);
        $localizedFields->addChild($shortDescription);
        
        // Add localized fields to panel
        $panel->addChild($localizedFields);
        
        // NOTE: description and shortDescription are defined inside the localized fields above.
        // Do not add duplicate (non-localized) fields with the same names to avoid SQL ambiguity.
        
        // Weight
        $weight = new ClassDefinition\Data\Numeric();
        $weight->setName("weight");
        $weight->setTitle("Weight");
        $weight->setInteger(false);
        $weight->setDecimalPrecision(6);
        $panel->addChild($weight);

        // Status
        $statusOptions = [
            ['key' => 'active', 'value' => 'Active'],
            ['key' => 'inactive', 'value' => 'Inactive'],
            ['key' => 'discontinued', 'value' => 'Discontinued']
        ];
        $status = new ClassDefinition\Data\Select();
        $status->setName("status");
        $status->setTitle("Status");
        $status->setOptions($statusOptions);
        $panel->addChild($status);

        // Visibility options
        $visibilityOptions = [
            ['key' => 'Not Visible Individually', 'value' => 'Not Visible Individually'],
            ['key' => 'Catalog', 'value' => 'Catalog'],
            ['key' => 'Search', 'value' => 'Search'],
            ['key' => 'Catalog, Search', 'value' => 'Catalog, Search']
        ];
        $visibility = new ClassDefinition\Data\Select();
        $visibility->setName("visibility");
        $visibility->setTitle("Visibility");
        $visibility->setOptions($visibilityOptions);
        $panel->addChild($visibility);

        // Price
        $price = new ClassDefinition\Data\Numeric();
        $price->setName("price");
        $price->setTitle("Price");
        $price->setInteger(false);
        $price->setDecimalPrecision(4);
        $panel->addChild($price);

        // Special price
        $specialPrice = new ClassDefinition\Data\Numeric();
        $specialPrice->setName("specialPrice");
        $specialPrice->setTitle("Special Price");
        $specialPrice->setInteger(false);
        $specialPrice->setDecimalPrecision(4);
        $panel->addChild($specialPrice);

        // Special price from/to dates
        $specialPriceFromDate = new ClassDefinition\Data\Datetime();
        $specialPriceFromDate->setName("specialPriceFromDate");
        $specialPriceFromDate->setTitle("Special Price From Date");
        $panel->addChild($specialPriceFromDate);

        $specialPriceToDate = new ClassDefinition\Data\Datetime();
        $specialPriceToDate->setName("specialPriceToDate");
        $specialPriceToDate->setTitle("Special Price To Date");
        $panel->addChild($specialPriceToDate);

        // Tax class
        $taxClassOptions = [
            ['key' => 'None', 'value' => 'None'],
            ['key' => 'Taxable Goods', 'value' => 'Taxable Goods'],
            ['key' => 'Shipping', 'value' => 'Shipping'],
            ['key' => 'Online Products', 'value' => 'Online Products']
        ];
        $taxClass = new ClassDefinition\Data\Select();
        $taxClass->setName("taxClass");
        $taxClass->setTitle("Tax Class");
        $taxClass->setOptions($taxClassOptions);
        $panel->addChild($taxClass);

        // URL key
        $urlKey = new ClassDefinition\Data\Input();
        $urlKey->setName("urlKey");
        $urlKey->setTitle("URL Key");
        $panel->addChild($urlKey);
        
        // Brand relation
        $brand = new ClassDefinition\Data\ManyToOneRelation();
        $brand->setName("brand");
        $brand->setTitle("Brand");
        $brand->setClasses(["Brand"]);
        $panel->addChild($brand);
        
        // Categories
        $categories = new ClassDefinition\Data\ManyToManyObjectRelation();
        $categories->setName("categories");
        $categories->setTitle("Categories");
        $categories->setClasses(["Category"]);
        $panel->addChild($categories);
        
        // Images gallery
        $images = new ClassDefinition\Data\ImageGallery();
        $images->setName("images");
        $images->setTitle("Product Images");
        $panel->addChild($images);

        // Additional images
        $additionalImages = new ClassDefinition\Data\ImageGallery();
        $additionalImages->setName("additionalImages");
        $additionalImages->setTitle("Additional Images");
        $panel->addChild($additionalImages);
        
        // Classification Store
        $classificationStore = new ClassDefinition\Data\Classificationstore();
        $classificationStore->setName("attributes");
        $classificationStore->setTitle("Product Attributes");
        $panel->addChild($classificationStore);
        
        // SEO Panel
        $seoPanel = new ClassDefinition\Layout\Panel();
        $seoPanel->setName("SEO");
        
        $metaTitle = new ClassDefinition\Data\Input();
        $metaTitle->setName("metaTitle");
        $metaTitle->setTitle("Meta Title");
        $seoPanel->addChild($metaTitle);
        
        $metaDescription = new ClassDefinition\Data\Textarea();
        $metaDescription->setName("metaDescription");
        $metaDescription->setTitle("Meta Description");
        $metaDescription->setHeight(100);
        $seoPanel->addChild($metaDescription);

        $metaKeywords = new ClassDefinition\Data\Input();
        $metaKeywords->setName("metaKeywords");
        $metaKeywords->setTitle("Meta Keywords");
        $seoPanel->addChild($metaKeywords);

        $panel->addChild($seoPanel);

        // Inventory Panel
        $inventoryPanel = new ClassDefinition\Layout\Panel();
        $inventoryPanel->setName("Inventory");

        // Quantity
        $quantity = new ClassDefinition\Data\Numeric();
        $quantity->setName("quantity");
        $quantity->setTitle("Quantity");
        $quantity->setInteger(false);
        $quantity->setDecimalPrecision(4);
        $inventoryPanel->addChild($quantity);

        // Stock status
        $stockStatusOptions = [
            ['key' => 'In Stock', 'value' => 'In Stock'],
            ['key' => 'Out of Stock', 'value' => 'Out of Stock']
        ];
        $stockStatus = new ClassDefinition\Data\Select();
        $stockStatus->setName("stockStatus");
        $stockStatus->setTitle("Stock Status");
        $stockStatus->setOptions($stockStatusOptions);
        $inventoryPanel->addChild($stockStatus);

        // Manage stock
        $manageStock = new ClassDefinition\Data\Checkbox();
        $manageStock->setName("manageStock");
        $manageStock->setTitle("Manage Stock");
        $inventoryPanel->addChild($manageStock);

        // Is quantity decimal
        $isQtyDecimal = new ClassDefinition\Data\Checkbox();
        $isQtyDecimal->setName("isQtyDecimal");
        $isQtyDecimal->setTitle("Is Qty Decimal");
        $inventoryPanel->addChild($isQtyDecimal);

        // Backorders
        $backordersOptions = [
            ['key' => 'No Backorders', 'value' => 'No Backorders'],
            ['key' => 'Allow Qty Below 0', 'value' => 'Allow Qty Below 0'],
            ['key' => 'Allow Qty Below 0 and Notify Customer', 'value' => 'Allow Qty Below 0 and Notify Customer']
        ];
        $backorders = new ClassDefinition\Data\Select();
        $backorders->setName("backorders");
        $backorders->setTitle("Backorders");
        $backorders->setOptions($backordersOptions);
        $inventoryPanel->addChild($backorders);

        // Min sale qty
        $minSaleQty = new ClassDefinition\Data\Numeric();
        $minSaleQty->setName("minSaleQty");
        $minSaleQty->setTitle("Min Sale Qty");
        $minSaleQty->setInteger(false);
        $minSaleQty->setDecimalPrecision(4);
        $inventoryPanel->addChild($minSaleQty);

        // Max sale qty
        $maxSaleQty = new ClassDefinition\Data\Numeric();
        $maxSaleQty->setName("maxSaleQty");
        $maxSaleQty->setTitle("Max Sale Qty");
        $maxSaleQty->setInteger(false);
        $maxSaleQty->setDecimalPrecision(4);
        $inventoryPanel->addChild($maxSaleQty);

        // Qty increments
        $qtyIncrements = new ClassDefinition\Data\Numeric();
        $qtyIncrements->setName("qtyIncrements");
        $qtyIncrements->setTitle("Qty Increments");
        $qtyIncrements->setInteger(false);
        $qtyIncrements->setDecimalPrecision(4);
        $inventoryPanel->addChild($qtyIncrements);

        $panel->addChild($inventoryPanel);
        $class->save();
        
        return $class;
    }
}