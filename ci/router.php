<?php

$pointer = getenv('PRACTICE_RELEASE_ROOT').DIRECTORY_SEPARATOR.'current.txt';
$release = is_file($pointer) ? trim((string) file_get_contents($pointer)) : '';

if (! preg_match('/^[0-9]+-[a-f0-9]{12}$/D', $release)) {
    http_response_code(503);
    echo 'No practice release is active.';
    return;
}

$public = dirname($pointer).DIRECTORY_SEPARATOR.'releases'.DIRECTORY_SEPARATOR.$release.DIRECTORY_SEPARATOR.'public';
$index = $public.DIRECTORY_SEPARATOR.'index.php';

if (! is_file($index)) {
    http_response_code(503);
    echo 'The practice release is unavailable.';
    return;
}

header('X-Practice-Release: '.$release);
$_SERVER['DOCUMENT_ROOT'] = $public;
$_SERVER['SCRIPT_FILENAME'] = $index;
$_SERVER['SCRIPT_NAME'] = '/index.php';
$_SERVER['PHP_SELF'] = '/index.php';
require $index;
