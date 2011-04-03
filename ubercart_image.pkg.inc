<?php

/**
 * @file
 * Define the image support package for enabling default Ubercart image support.
 */


/**
 * Implementation of hook_pkg_info().
 */
function ubercart_image_pkg_info() {
  // Include the CCK
  module_load_include('inc', 'filefield', 'filefield_widget');
  module_load_include('inc', 'imagefield', 'imagefield_widget');

  // Determine the image API plugin module to use.
  $plugin = class_exists('imagick') ? 'imageapi_imagemagick' : 'imageapi_gd';

  return array(
    'title' => t('Image support'),
    'description' => t('This package installs default image support for Ubercart products and integrates them into various parts of the store. It uses Lightbox2 for popup displays on product pages.'),
    'modules' => array('content', 'filefield', 'imageapi', $plugin, 'imagefield', 'imagecache', 'imagecache_ui', 'lightbox2'),
  );
}

/**
 * Implementation of hook_pkg_postinstall().
 */
function ubercart_image_pkg_postinstall() {
  uc_product_add_default_image_field();
}
