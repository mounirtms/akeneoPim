<?php

namespace Migration;

class MigrationAutoloader
{
    public static function register()
    {
        spl_autoload_register(function ($class) {
            echo "Looking for class: $class\n";
            // Define the base directory for the namespace
            $base_dir = __DIR__ . '/Migration/';

            // Does the class use the namespace prefix?
            $prefix = 'Migration\\';
            $len = strlen($prefix);
            if (strncmp($prefix, $class, $len) !== 0) {
                // no, move to the next registered autoloader
                return;
            }

            // Get the relative class name
            $relative_class = substr($class, $len);

            // Replace the namespace prefix with the base directory, replace namespace
            // separators with directory separators in the relative class name, append
            // with .php
            $file = $base_dir . str_replace('\\', '/', $relative_class) . '.php';

            // if the file exists, require it
            if (file_exists($file)) {
                require $file;
            }
        });
    }
}