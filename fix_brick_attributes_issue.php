<?php

include_once __DIR__ . '/vendor/autoload.php';

\Pimcore\Bootstrap::setProjectRoot();
\Pimcore\Bootstrap::bootstrap();

echo "=== Fixing Object Brick Attributes Issue ===\n\n";

try {
    // Try to directly access object brick definitions to identify the problematic one
    echo "Loading object brick definitions...\n";
    
    // Try to load all object brick definitions
    $brickDefinitions = \Pimcore\Model\DataObject\Objectbrick\Definition::getList();
    
    echo "Found " . count($brickDefinitions) . " object brick definitions\n";
    
    foreach ($brickDefinitions as $brickDefinition) {
        echo "Checking brick: " . $brickDefinition->getKey() . "\n";
        
        // Try to access the class definitions
        $classDefinitions = $brickDefinition->getClassDefinitions();
        
        if (!empty($classDefinitions)) {
            foreach ($classDefinitions as $classDef) {
                echo "  - Class: " . $classDef['classname'] . ", Field: " . $classDef['fieldname'] . "\n";
                
                // Check if this is the problematic "attributes" field
                if ($classDef['fieldname'] === 'attributes') {
                    echo "    *** Found problematic 'attributes' field reference ***\n";
                    
                    // Try to load the class
                    $class = \Pimcore\Model\DataObject\ClassDefinition::getByName($classDef['classname']);
                    if ($class) {
                        echo "    Class loaded successfully\n";
                        
                        // Check if the field exists
                        $fieldDefinition = $class->getFieldDefinition('attributes');
                        if (!$fieldDefinition) {
                            echo "    Field 'attributes' does not exist in class " . $classDef['classname'] . "\n";
                            
                            // Remove this class definition from the brick
                            echo "    Removing problematic class definition...\n";
                            
                            // Filter out this class definition
                            $newClassDefinitions = array_filter($classDefinitions, function($def) {
                                return $def['fieldname'] !== 'attributes';
                            });
                            
                            // Update the brick definition
                            $brickDefinition->setClassDefinitions(array_values($newClassDefinitions));
                            
                            // Save the brick definition
                            try {
                                $brickDefinition->save();
                                echo "    Brick definition updated successfully\n";
                            } catch (Exception $saveException) {
                                echo "    Failed to save brick definition: " . $saveException->getMessage() . "\n";
                            }
                        } else {
                            echo "    Field 'attributes' exists in class\n";
                        }
                    } else {
                        echo "    Failed to load class " . $classDef['classname'] . "\n";
                    }
                }
            }
        }
    }
    
    // Now try to rebuild classes
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
    
    echo "\n=== Fix Process Completed ===\n";
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
    echo "Trace: " . $e->getTraceAsString() . "\n";
}