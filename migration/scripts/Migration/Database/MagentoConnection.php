<?php

namespace Migration\Database;

use PDO;
use PDOException;

class MagentoConnection
{
    private $pdo;
    private static $instance = null;
    
    public function __construct()
    {
        try {
            $this->pdo = new PDO(
                'mysql:host=127.0.0.1;port=3307;dbname=technadminy7_dBT8x12y22;charset=utf8mb4',
                'root',
                'YourNewStrongPassword',
                [
                    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                    PDO::MYSQL_ATTR_INIT_COMMAND => "SET NAMES utf8mb4",
                    PDO::ATTR_TIMEOUT => 60,
                    PDO::MYSQL_ATTR_USE_BUFFERED_QUERY => true
                ]
            );
            
            // Test connection
            $this->pdo->query("SELECT 1");
            
        } catch (PDOException $e) {
            throw new \RuntimeException("Database connection failed: " . $e->getMessage());
        }
    }
    
    public static function getInstance()
    {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }
    
    public function getAttributeSets()
    {
        try {
            $sql = "SELECT * FROM eav_attribute_set WHERE entity_type_id = 
                   (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'catalog_product')";
            return $this->pdo->query($sql)->fetchAll();
        } catch (PDOException $e) {
            error_log("Error fetching attribute sets: " . $e->getMessage());
            return [];
        }
    }
    
    public function getProductAttributes()
    {
        try {
            $sql = "SELECT 
                        ea.attribute_id,
                        ea.attribute_code,
                        ea.backend_type,
                        ea.frontend_input,
                        ea.is_required,
                        ea.is_user_defined,
                        eea.is_global,
                        eea.is_searchable,
                        eea.is_filterable
                    FROM eav_attribute ea
                    LEFT JOIN catalog_eav_attribute eea ON ea.attribute_id = eea.attribute_id
                    WHERE ea.entity_type_id = 
                        (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'catalog_product')";
            return $this->pdo->query($sql)->fetchAll();
        } catch (PDOException $e) {
            error_log("Error fetching product attributes: " . $e->getMessage());
            return [];
        }
    }
    
    public function getCategories()
    {
        try {
            $sql = "SELECT DISTINCT
                        e.entity_id,
                        vn.value as name,
                        e.parent_id,
                        e.position,
                        vd.value as description
                    FROM catalog_category_entity e
                    LEFT JOIN catalog_category_entity_varchar vn ON e.entity_id = vn.entity_id 
                        AND vn.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'name' 
                            AND entity_type_id = (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'catalog_category'))
                    LEFT JOIN catalog_category_entity_text vd ON e.entity_id = vd.entity_id 
                        AND vd.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'description' 
                            AND entity_type_id = (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'catalog_category'))
                    WHERE e.level > 0
                    ORDER BY e.parent_id, e.position";
            return $this->pdo->query($sql)->fetchAll();
        } catch (PDOException $e) {
            error_log("Error fetching categories: " . $e->getMessage());
            return [];
        }
    }
    
    public function getProducts($limit = null, $offset = 0)
    {
        try {
            $sql = "SELECT DISTINCT
                        e.entity_id,
                        e.sku,
                        vn.value as name,
                        vd.value as description,
                        vs.value as short_description,
                        e.created_at,
                        e.updated_at
                    FROM catalog_product_entity e
                    LEFT JOIN catalog_product_entity_varchar vn ON e.entity_id = vn.entity_id 
                        AND vn.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'name' 
                            AND entity_type_id = (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'catalog_product'))
                    LEFT JOIN catalog_product_entity_text vd ON e.entity_id = vd.entity_id 
                        AND vd.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'description' 
                            AND entity_type_id = (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'catalog_product'))
                    LEFT JOIN catalog_product_entity_text vs ON e.entity_id = vs.entity_id 
                        AND vs.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'short_description' 
                            AND entity_type_id = (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'catalog_product'))";
                            
            if ($limit) {
                $sql .= " LIMIT " . (int)$offset . ", " . (int)$limit;
            }
            
            return $this->pdo->query($sql)->fetchAll();
        } catch (PDOException $e) {
            error_log("Error fetching products: " . $e->getMessage());
            return [];
        }
    }
    
    public function getProductCount()
    {
        try {
            $sql = "SELECT COUNT(DISTINCT e.entity_id) as count FROM catalog_product_entity e";
            return $this->pdo->query($sql)->fetch()['count'];
        } catch (PDOException $e) {
            error_log("Error getting product count: " . $e->getMessage());
            return 0;
        }
    }
    
    public function getProductCategories($productId)
    {
        try {
            $sql = "SELECT category_id FROM catalog_category_product WHERE product_id = ?";
            $stmt = $this->pdo->prepare($sql);
            $stmt->execute([$productId]);
            return $stmt->fetchAll(PDO::FETCH_COLUMN);
        } catch (PDOException $e) {
            error_log("Error fetching product categories for product $productId: " . $e->getMessage());
            return [];
        }
    }
    
    public function getProductImages($productId)
    {
        try {
            $sql = "SELECT 
                        g.value as file,
                        v.position,
                        v.label
                    FROM catalog_product_entity_media_gallery g
                    LEFT JOIN catalog_product_entity_media_gallery_value v ON g.value_id = v.value_id
                    WHERE g.entity_id = ?
                    ORDER BY v.position";
            $stmt = $this->pdo->prepare($sql);
            $stmt->execute([$productId]);
            return $stmt->fetchAll();
        } catch (PDOException $e) {
            error_log("Error fetching product images for product $productId: " . $e->getMessage());
            return [];
        }
    }
}