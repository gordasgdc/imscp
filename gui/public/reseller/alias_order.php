<?php
/**
 * i-MSCP - internet Multi Server Control Panel
 *
 * The contents of this file are subject to the Mozilla Public License
 * Version 1.1 (the "License"); you may not use this file except in
 * compliance with the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS"
 * basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
 * License for the specific language governing rights and limitations
 * under the License.
 *
 * The Original Code is "VHCS - Virtual Hosting Control System".
 *
 * The Initial Developer of the Original Code is moleSoftware GmbH.
 * Portions created by Initial Developer are Copyright (C) 2001-2006
 * by moleSoftware GmbH. All Rights Reserved.
 *
 * Portions created by the ispCP Team are Copyright (C) 2006-2010 by
 * isp Control Panel. All Rights Reserved.
 *
 * Portions created by the i-MSCP Team are Copyright (C) 2010-2018 by
 * i-MSCP - internet Multi Server Control Panel. All Rights Reserved.
 */

use iMSCP_Registry as Registry;

/***********************************************************************************************************************
 * Main
 */

require 'imscp-lib.php';

check_login('reseller');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onResellerScriptStart);
resellerHasFeature('domain_aliases') or showBadRequestErrorPage();

if (isset($_GET['action']) && $_GET['action'] === 'reject' && isset($_GET['id'])) {
    $id = intval($_GET['id']);
    $stmt = exec_query(
        '
            SELECT alias_id
            FROM domain_aliasses
            JOIN domain USING(domain_id)
            JOIN admin ON(admin_id = domain_admin_id)
            WHERE alias_id = ?
            AND created_by = ?
        ',
        [$id, $_SESSION['user_id']]
    );
    if (!$stmt->rowCount()) {
        showBadRequestErrorPage();
    }

    /** @var iMSCP_Database $db */
    $db = Registry::get('iMSCP_Application')->getDatabase();

    try {
        $db->beginTransaction();
        exec_query("DELETE FROM php_ini WHERE domain_id = ? AND domain_type = 'als'", [$id]);
        exec_query("DELETE FROM domain_aliasses WHERE alias_id = ? AND alias_status = 'ordered'", [$id]);
        $db->commit();
        write_log(sprintf('An alias order has been rejected by %s.', $_SESSION['user_logged']), E_USER_NOTICE);
        set_page_message('Alias order successfully rejected.', 'success');
    } catch (iMSCP_Exception $e) {
        $db->rollBack();
        write_log(sprintf('System was unable to reject alias order: %s', $e->getMessage()), E_USER_ERROR);
        set_page_message('Could not reject alias order. An unexpected error occurred.');
    }

    redirectTo('alias.php');
}

if (!isset($_GET['action']) || $_GET['action'] !== 'validate' || !isset($_GET['id'])) {
    showBadRequestErrorPage();
}

$id = intval($_GET['id']);
$stmt = exec_query(
    "
        SELECT alias_name, domain_id, email
        FROM domain_aliasses
        JOIN domain USING(domain_id)
        JOIN admin ON(admin_id = domain_admin_id)
        WHERE alias_id = ?
        AND alias_status = 'ordered'
        AND created_by = ?
    ",
    [$id, $_SESSION['user_id']]
);
if (!$stmt->rowCount()) {
    showBadRequestErrorPage();
}

$row = $stmt->fetch();

/** @var iMSCP_Database $db */
$db = Registry::get('iMSCP_Application')->getDatabase();

try {
    $db->beginTransaction();

    Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onBeforeAddDomainAlias, [
        'domainId'        => $row['domain_id'],
        'domainAliasName' => $row['alias_name']
    ]);

    exec_query("UPDATE domain_aliasses SET alias_status = 'toadd' WHERE alias_id = ?", [$id]);

    $cfg = Registry::get('config');

    createDefaultMailAccounts($row['domain_id'], $row['email'], $row['alias_name'], MT_ALIAS_FORWARD, $id);

    Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onAfterAddDomainAlias, [
        'domainId'        => $row['domain_id'],
        'domainAliasName' => $row['alias_name'],
        'domainAliasId'   => $id
    ]);

    $db->commit();
    send_request();
    write_log(sprintf('An alias order has been validated by %s.', $_SESSION['user_logged']), E_USER_NOTICE);
    set_page_message(tr('Order successfully validated.'), 'success');
} catch (iMSCP_Exception $e) {
    $db->rollBack();
    write_log(sprintf('System was unable to validate alias order: %s', $e->getMessage()), E_USER_ERROR);
    set_page_message('Could not validate alias order. An unexpected error occurred.', 'error');
}

redirectTo('alias.php');
