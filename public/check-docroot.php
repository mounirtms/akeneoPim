<?php
echo "DocumentRoot check\n";
echo "Current script: " . __FILE__ . "\n";
echo "Current directory: " . getcwd() . "\n";
echo "Server DocumentRoot: " . $_SERVER['DOCUMENT_ROOT'] ?? 'Not set' . "\n";
?>