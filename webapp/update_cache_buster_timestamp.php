<?php
/**
 * Update cache buster to timestamp-based version
 * This ensures Cloudflare cache is bypassed
 */

$templateFile = __DIR__ . '/../vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/views/index.html.twig';
$timestamp = '1777300451';

if (!file_exists($templateFile)) {
    die("ERROR: Template not found\n");
}

$content = file_get_contents($templateFile);

// Replace cache_buster with timestamp
$content = preg_replace(
    '/{% set cache_buster = "[^"]*" %}/',
    '{% set cache_buster = "' . $timestamp . '" %}',
    $content
);

// Backup
copy($templateFile, $templateFile . '.backup.' . $timestamp);

// Write
file_put_contents($templateFile, $content);

echo "✅ Cache buster updated to: $timestamp\n";
echo "Backed up to: " . $templateFile . ".backup.$timestamp\n";
