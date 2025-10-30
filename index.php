<?php
// Redirect all requests to the public directory
if (file_exists(__DIR__ . '/public/' . $_SERVER['REQUEST_URI'])) {
    // If the requested file exists in public, serve it directly
    return false;
} else {
    // Otherwise, let the public front controller handle it
    require_once __DIR__ . '/public/index.php';
}