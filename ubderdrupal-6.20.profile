<?php

/**
 * @file
 * Ubercart installation profile.
 */


/**
 * Return a description of the profile for the initial installation screen.
 *
 * @return
 *   An array with keys 'name' and 'description' describing this profile,
 *   and optional 'language' to override the language selection for
 *   language-specific profiles, e.g., 'language' => 'fr'.
 */
function uberdrupal_profile_details() {
  return array(
    'name' => 'UberDrupal',
    'description' => 'Install Drupal with the Acquia Prosper theme by Top Notch Themes and e-commerce functionality provided by Ubercart and other contributed modules.',
  );
}

/**
 * Return an array of the modules to be enabled when this profile is installed.
 *
 * The following required core modules are always enabled:
 * 'block', 'filter', 'node', 'system', 'user'.
 *
 * @return
 *  An array of modules to be enabled.
 */
function uberdrupal_profile_modules() {
  return array(
    // Core Drupal modules:
    'block',
    'filter',
    'node',
    'system',
    'user',
    'dblog',
    'help',
    'menu',
    'path',
    'taxonomy',
    'color',

    // Ubercart dependencies:
    'ca',
    'token',

    // Ubercart modules:
    'uc_store',
    'uc_product',
    'uc_order',
    'uc_catalog',
    'uc_cart',
  );
}

/**
 * Return a list of tasks that this profile supports.
 *
 * @return
 *   A keyed array of tasks the profile will perform during the final stage. The
 *   keys of the array will be used internally, while the values will be
 *   displayed to the user in the installer task list.
 */
function uberdrupal_profile_task_list() {
  return array(
    'config' => st('Configure store'),
    'features' => st('Install features'),
  );
}

/**
 * Perform installation tasks for this installation profile.
 */
function uberdrupal_profile_tasks(&$task, $url) {
  switch ($task) {
    // Perform tasks when the installation form is initially submitted and all
    // the specified modules have been installed.
    case 'profile':
      // Setup the page content type.
      _uberdrupal_setup_page();

      // Toggle the node info display for products.
      $settings = variable_get('theme_settings', array());
      $settings['toggle_node_info_product'] = 0;
      $settings['toggle_node_info_product_kit'] = 0;
      variable_set('theme_settings', $settings);

      // Use a working store dashboard setting.
      variable_set('uc_store_admin_page_display', 4);

      // Turn off the Ubercart store footer.
      variable_set('uc_footer_message', 'none');

      // Install the Administration Menu module if it exists.
      uberdrupal_install_module('admin_menu');

      // Install Acquia Prosper if the necessary module and themes exist.
      _uberdrupal_install_theme();

      // Update the menu router information.
      menu_rebuild();

      // Import every country available.
      require_once drupal_get_path('module', 'uc_store') .'/uc_store.admin.inc';

      // Get an array of all the files in the countries directory.
      $files = _country_import_list();

      // Unset any countries from the files array that have already been imported.
      $result = db_query("SELECT * FROM {uc_countries} ORDER BY country_name ASC");
      while ($country = db_fetch_object($result)) {
        unset($files[$country->country_id]);
      }

      // Install any country remaining in the files array.
      foreach ($files as $file) {
        uc_country_import($file['file']);
      }

      // Setup a catalog term and basic product.
      $edit = array('vid' => 1, 'name' => t('Products'));
      taxonomy_save_term($edit);

      // Create some instructional and example nodes.
      _uberdrupal_create_nodes();

      // Setup some default menu items.
      _uberdrupal_setup_menu_items();

      // Add some basic permissions for anonymous and authenticated users.
      db_query("UPDATE {permission} SET perm = CONCAT(perm, ', view catalog') WHERE pid = 1");
      db_query("UPDATE {permission} SET perm = CONCAT(perm, ', view catalog, view own orders') WHERE pid = 2");

      // Set $task to next task so the UI will be correct.
      $task = 'config';
      drupal_set_title(t('Configure store'));
      return drupal_get_form('uberdrupal_store_settings_form', $url);

    // Perform tasks when the store configuration form has been submitted.
    case 'config':
      // Save the values from the store configuration form.
      uberdrupal_store_settings_form_submit();

      // Move to the feature installation task.
      $task = 'features';
      drupal_set_title(t('Install features'));
      return drupal_get_form('uberdrupal_features_form', $url);

    // Perform tasks when the feature selection form has been submitted.
    case 'features':
      // Install the selected features at this time.
      uberdrupal_features_form_submit();

      // Move to the completion task.
      $task = 'profile-finished';
      break;
  }
}

/**
 * Build the Ubercart store configuration form.
 *
 * @param $form_state
 * @param $url
 *   URL of current installer page, provided by installer.
 */
function uberdrupal_store_settings_form(&$form_state, $url) {
  $form = array(
    '#action' => $url,
    '#redirect' => FALSE,
  );

  // Add the store contact information to the form.
  $form['uc_store_contact_info'] = array(
    '#type' => 'fieldset',
    '#title' => t('Contact information'),
  );

  $form['uc_store_contact_info']['uc_store_name'] = uc_textfield(t('Store name'), variable_get('site_name', NULL), FALSE, NULL, 64);
  $form['uc_store_contact_info']['uc_store_owner'] = uc_textfield(t('Store owner'), NULL, FALSE, NULL, 64);

  $form['uc_store_contact_info']['uc_store_phone'] = uc_textfield(t('Phone number'), NULL, FALSE);
  $form['uc_store_contact_info']['uc_store_fax'] = uc_textfield(t('Fax number'), NULL, FALSE);

  $form['uc_store_contact_info']['uc_store_email'] = array(
    '#type' => 'textfield',
    '#title' => t('E-mail address'),
    '#description' => NULL,
    '#size' => 32,
    '#maxlength' => 128,
    '#required' => FALSE,
  );

  $form['uc_store_contact_info']['uc_store_email_include_name'] = array(
    '#type' => 'checkbox',
    '#title' => t('Include the store name in the from line of store e-mails.'),
    '#description' => t('May not be available on all server configurations. Turn off if this causes problems.'),
    '#default_value' => TRUE,
  );

  $form['uc_store_address'] = array(
    '#type' => 'fieldset',
    '#title' => t('Store address'),
  );

  $form['uc_store_address']['uc_store_street1'] = uc_textfield(uc_get_field_name('street1'), NULL, FALSE, NULL, 128);
  $form['uc_store_address']['uc_store_street2'] = uc_textfield(uc_get_field_name('street2'), NULL, FALSE, NULL, 128);
  $form['uc_store_address']['uc_store_city'] = uc_textfield(uc_get_field_name('city'), NULL, FALSE);
  $form['uc_store_address']['uc_store_country'] = uc_country_select(uc_get_field_name('country'), uc_store_default_country());

  $country_id = uc_store_default_country();
  $form['uc_store_address']['uc_store_zone'] = uc_zone_select(uc_get_field_name('zone'), NULL, NULL, $country_id);
  $form['uc_store_address']['uc_store_postal_code'] = uc_textfield(uc_get_field_name('postal_code'), NULL, FALSE, NULL, 10);

  $form['submit'] = array(
    '#type' => 'submit',
    '#value' => t('Save and continue'),
  );

  return $form;
}

function uberdrupal_store_settings_form_submit() {
  $form_state = array('values' => $_POST);
  system_settings_form_submit(array(), $form_state);
}

/**
 * Build the Ubercart feature selection form.
 *
 * @param $form_state
 * @param $url
 *   URL of current installer page, provided by installer.
 */
function uberdrupal_features_form($form_state, $url) {
  $form = array(
    '#action' => $url,
    '#redirect' => FALSE,
  );

  $form['features'] = array(
    '#type' => 'fieldset',
    '#title' => t('Available features'),
    '#description' => t('Select as many features as you wish to enable in your store at this time.'),
    '#tree' => TRUE,
  );

  // Loop through all the .pkg.inc feature include files in the profile.
  foreach (uberdrupal_list_features() as $filename => $file) {
    require_once $filename;

    // Get the info for the feature from its implementation of hook_pkg_info().
    $func = substr($file->name, 0, strlen($file->name) - 4) .'_pkg_info';
    $feature_info = $func();

    $form['features'][$file->name] = array(
      '#type' => 'checkbox',
      '#title' => $feature_info['title'],
      '#description' => $feature_info['description'],
    );
  }

  $form['submit'] = array(
    '#type' => 'submit',
    '#value' => st('Install features'),
  );

  return $form;
}

function uberdrupal_features_form_submit() {
  $postprocess = array();

  // Loop through all the .pkg.inc feature include files in the profile.
  foreach (uberdrupal_list_features() as $filename => $file) {
    // If this feature was selected for inclusion in the form...
    if ($_POST['features'][$file->name]) {
      require_once $filename;

      $base = substr($file->name, 0, strlen($file->name) - 4);
      $func = $base .'_pkg_info';
      $feature_info = $func();

      // Install all the modules required by the feature.
      foreach ((array) $feature_info['modules'] as $module) {
        drupal_load('module', $module);
        drupal_install_modules(array($module));
      }

      $postprocess[] = $base . '_pkg_postinstall';
    }
  }

  foreach ($postprocess as $process) {
    if (function_exists($process)) {
      $process();
    }
  }
}

/**
 * Return an array of .pkg.inc files in the profile directory keyed by filename.
 */
function uberdrupal_list_features() {
  return file_scan_directory('profiles/uberdrupal', '.*\.pkg.inc');
}

/**
 * Install a module or array of modules if the modules exist in the site.
 *
 * @param $module
 *   A module name or array of module names to install if the modules exist.
 * @return
 *   Returns TRUE or FALSE to indicate whether a module actually existed; no
 *     return value for multiple installations by array.
 */
function uberdrupal_install_module($module) {
  // If an array was passed...
  if (is_array($module)) {
    // Loop through the array and install each one.
    foreach ($module as $mod) {
      uberdrupal_install_module($mod);
    }
  }
  else {
    // Otherwise go ahead and attempt the install.
    if (drupal_get_path('module', $module)) {
      drupal_load('module', $module);
      drupal_install_modules(array($module));
      return TRUE;
    }
    else {
      return FALSE;
    }
  }
}

/**
 * Setup the page content type.
 */
function _uberdrupal_setup_page() {
  require_once 'modules/comment/comment.module';

  // Insert the page node type into the database.
  $type = array(
    'type' => 'page',
    'name' => st('Page'),
    'module' => 'node',
    'description' => st("A <em>page</em>, similar in form to a <em>story</em>, is a simple method for creating and displaying information that rarely changes, such as an \"About us\" section of a website. By default, a <em>page</em> entry does not allow visitor comments and is not featured on the site's initial home page."),
    'custom' => TRUE,
    'modified' => TRUE,
    'locked' => FALSE,
    'help' => '',
    'min_word_count' => '',
  );

  $type = (object) _node_type_set_defaults($type);
  node_type_save($type);

  // Default page to not be promoted and have comments disabled.
  variable_set('node_options_page', array('status'));
  variable_set('comment_page', COMMENT_NODE_DISABLED);

  // Don't display date and author information for page nodes by default.
  $theme_settings = variable_get('theme_settings', array());
  $theme_settings['toggle_node_info_page'] = FALSE;
  variable_set('theme_settings', $theme_settings);
}

// Install Acquia Prosper if possible.
function _uberdrupal_install_theme() {
  $themes = array_keys(system_theme_data());

  if (drupal_get_path('module', 'skinr') && in_array('fusion_core', $themes) && in_array('acquia_prosper', $themes)) {
    // First install Skinr.
    uberdrupal_install_module('skinr');

    // Then install the themes.
    db_query("UPDATE {system} SET status = 1 WHERE type = 'theme' AND (name = '%s' OR name = '%s')", 'fusion_core', 'acquia_prosper');

    // And finally set Acquia Prosper to be the default.
    variable_set('theme_default', 'acquia_prosper');
  }

  // Configure blocks for Acquia Prosper.
  _uberdrupal_setup_blocks();
}

// Configure the blocks for Acquia Prosper.
function _uberdrupal_setup_blocks() {
  $blocks = array(
    array('module' => 'menu', 'delta' => 'primary-links', 'weight' => -5, 'region' => 'footer'),
    array('module' => 'user', 'delta' => 0, 'weight' => -4, 'region' => 'sidebar_first', 'pages' => 'cart/checkout*'),
    array('module' => 'user', 'delta' => 1, 'weight' => -3, 'region' => 'sidebar_first', 'pages' => 'cart/checkout*'),
    array('module' => 'uc_cart', 'delta' => 0, 'weight' => -5, 'region' => 'header', 'pages' => 'cart/checkout*'),
    array('module' => 'uc_catalog', 'delta' => 0, 'weight' => -5, 'region' => 'sidebar_first', 'pages' => 'cart/checkout*'),
  );

  foreach ($blocks as $block) {
    $block['theme'] = 'acquia_prosper';
    $block['status'] = 1;
    drupal_write_record('blocks', $block);
  }

  db_query("INSERT INTO {blocks_roles} (module, delta, rid) VALUES ('%s', %d, %d)", 'user', 1, 2);

  $settings = array(
    'block' => array(
      'uc_catalog-0' => array(
        'prosper-general-styles' => 'prosper-gray-rounded-style prosper-rounded-title',
      ),
      'uc_cart-0' => array(
        'grid16-width' => 'grid16-5',
        'fusion-alignment' => 'fusion-right',
        'prosper-general-styles' => 'prosper-shoppingcart-dark',
      ),
      'menu-primary-links' => array(
        'fusion-menu' => 'fusion-inline-menu',
      ),
    ),
  );
  variable_set('skinr_acquia_prosper', $settings);
}

// Install a few primary link menu items by default.
function _uberdrupal_setup_menu_items() {
  $items = array(
    array('link_path' => '<front>', 'link_title' => t('Home'), 'weight' => 0),
    array('link_path' => 'catalog', 'link_title' => t('Catalog'), 'weight' => 1),
    array('link_path' => 'node/2', 'link_title' => t('About'), 'weight' => 2),
  );

  foreach ($items as $item) {
    $item += array(
      'mlid' => 0,
      'module' => 'menu',
      'has_children' => 0,
      'options' => array(
        'attributes' => array(
          'title' => '',
        ),
      ),
      'customized' => 1,
      'original_item' => array(
        'link_title' => '',
        'mlid' => 0,
        'plid' => 0,
        'menu_name' => 'primary-links',
        'weight' => 1,
        'link_path' => '',
        'options' => array(),
        'module' => 'menu',
        'expanded' => 0,
        'hidden' => 0,
        'has_children' => 0,
      ),
      'description' => '',
      'expanded' => 0,
      'parent' => 'primary-links:0',
      'hidden' => 0,
      'plid' => 0,
      'menu_name' => 'primary-links',
    );
    menu_link_save($item);
  }
}

// Create an instructions page, an example product, and an about page.
function _uberdrupal_create_nodes() {
  // Add an instructional page and set it to the front page.
  $node = new stdClass();
  $node->title = 'Welcome to your store!';
  $node->body = "Now that you have completed installation, there is still plenty of work to do to make sure your store is ready for business.\n\n<strong>TODO:</strong> Post your ideas on what steps to include here at http://drupal.org/node/625906.";
  $node->type = 'page';
  $node->created = time();
  $node->changed = time();
  $node->status = 1;
  $node->promote = 1;
  $node->sticky = 0;
  $node->format = 1;
  $node->uid = 1;
  $node->language = 'en';
  node_save($node);

  variable_set('site_frontpage', 'node/1');

  $node = new stdClass();
  $node->title = 'About us';
  $node->body = 'This is a sample about us page that you can edit to fill with information about your store.';
  $node->type = 'page';
  $node->created = time();
  $node->changed = time();
  $node->path = 'about';
  $node->status = 1;
  $node->promote = 0;
  $node->sticky = 0;
  $node->format = 1;
  $node->uid = 1;
  $node->language = 'en';
  node_save($node);

  $node = new stdClass();
  $node->title = 'Example Product';
  $node->body = 'This is a simple example product that you can modify or delete. Use it to test checkout for a shippable item.';
  $node->type = 'product';
  $node->created = time();
  $node->changed = time();
  $node->status = 1;
  $node->promote = 0;
  $node->sticky = 0;
  $node->format = 1;
  $node->uid = 1;
  $node->language = 'en';
  $node->model = 'PRODUCT';
  $node->list_price = 15;
  $node->cost = 5;
  $node->sell_price = 10;
  $node->weight = 5;
  $node->weight_units = 'lb';
  $node->default_qty = 1;
  $node->shippable = 1;
  node_save($node);

  taxonomy_node_save($node, array(1));
}
