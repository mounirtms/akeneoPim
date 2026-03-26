<?php

include_once __DIR__ . '/vendor/autoload.php';

\Pimcore\Bootstrap::setProjectRoot();
\Pimcore\Bootstrap::bootstrap();

echo "=== Fixing Object Brick Definition Issue ===\n\n";

try {
    // Try to rebuild classes with force option to bypass errors
    echo "Attempting to rebuild classes with force option...\n";
    
    // We need to manually fix the object brick definition
    // First, let's check if we can access the object brick definition
    
    $db = \Pimcore\Db::get();
    
    // Look for object brick definition that might contain the problematic "attributes" field
    echo "Looking for object brick definitions in the database...\n";
    
    // Check classification store groups
    echo "Checking classification store groups...\n";
    $groups = $db->fetchAllAssociative("SELECT * FROM classificationstore_groups");
    foreach ($groups as $group) {
        echo "- Group ID: " . $group['id'] . ", Name: " . $group['name'] . "\n";
    }
    
    // Check classification store relations
    echo "Checking classification store relations...\n";
    $relations = $db->fetchAllAssociative("SELECT * FROM classificationstore_relations LIMIT 5");
    foreach ($relations as $relation) {
        echo "- Relation: Group ID: " . $relation['groupId'] . ", Key ID: " . $relation['keyId'] . "\n";
    }
    
    // Try to fix by adding the missing "attributes" key to classification store
    echo "\nAdding 'attributes' key to classification store...\n";
    
    // Check if the 'attributes' key already exists
    $existingKey = $db->fetchOne(
        "SELECT id FROM classificationstore_keys WHERE name = ?", 
        ['attributes']
    );
    
    if (!$existingKey) {
        echo "Creating 'attributes' key in classification store...\n";
        
        $insertStmt = $db->prepare("
            INSERT INTO classificationstore_keys 
            (storeId, name, title, type, creationDate, modificationDate, enabled) 
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ");
        
        $now = time();
        $insertStmt->execute([
            1,              // storeId
            'attributes',   // name
            'Attributes',   // title
            'input',        // type (generic input field)
            $now,           // creationDate
            $now,           // modificationDate
            1               // enabled
        ]);
        
        $keyId = $db->lastInsertId();
        echo "Created 'attributes' key with ID: " . $keyId . "\n";
        
        // Add relation to a group (assuming group 1 exists)
        echo "Adding relation to group...\n";
        $insertRelationStmt = $db->prepare("
            INSERT INTO classificationstore_relations 
            (storeId, groupId, keyId) 
            VALUES (?, ?, ?)
        ");
        
        $insertRelationStmt->execute([
            1,  // storeId
            1,  // groupId (assuming group 1 exists)
            $keyId  // keyId
        ]);
        
        echo "Added relation for 'attributes' key.\n";
    } else {
        echo "'attributes' key already exists with ID: " . $existingKey . "\n";
    }
    
    // Try to rebuild classes now
    echo "\nRebuilding classes...\n";
    $process = new \Symfony\Component\Process\Process([
        './bin/console', 
        'pimcore:deployment:classes-rebuild', 
        '--create-classes'
    ]);
    $process->setWorkingDirectory(__DIR__);
    $process->run();
    
    if (!$process->isSuccessful()) {
        echo "Class rebuilding failed: " . $process->getErrorOutput() . "\n";
        echo "Output: " . $process->getOutput() . "\n";
    } else {
        echo "Classes rebuilt successfully.\n";
    }
    
    // Clear cache
    echo "\nClearing cache...\n";
    $process = new \Symfony\Component\Process\Process(['./bin/console', 'cache:clear']);
    $process->setWorkingDirectory(__DIR__);
    $process->run();
    
    if (!$process->isSuccessful()) {
        echo "Cache clearing failed: " . $process->getErrorOutput() . "\n";
    } else {
        echo "Cache cleared successfully.\n";
    }
    
    echo "\n=== Object Brick Fix Attempt Completed ===\n";
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
    echo "Trace: " . $e->getTraceAsString() . "\n";
}