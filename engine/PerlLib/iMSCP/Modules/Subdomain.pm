=head1 NAME

 iMSCP::Modules::Subdomain - Module for processing of subdomain entities

=cut

# i-MSCP - internet Multi Server Control Panel
# Copyright (C) 2010-2018 Laurent Declercq <l.declercq@nuxwin.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA

package iMSCP::Modules::Subdomain;

use strict;
use warnings;
use File::Spec;
use iMSCP::Boolean;
use parent 'iMSCP::Modules::Abstract';

=head1 DESCRIPTION

 Module for processing of subdomain entities.

=head1 PUBLIC METHODS

=over 4

=item getEntityType( )

 See iMSCP::Modules::Abstract::getEntityType()

=cut

sub getEntityType
{
    my ( $self ) = @_;

    'Subdomain';
}

=item handleEntity( $entityId )

 See iMSCP::Modules::Abstract::handleEntity()

=cut

sub handleEntity
{
    my ( $self, $entityId ) = @_;

    $self->_loadEntityData( $entityId );

    if ( $self->{'_data'}->{'STATUS'} =~ /^to(?:add|change|enable)$/ ) {
        $self->_add();
    } elsif ( $self->{'_data'}->{'STATUS'} eq 'todelete' ) {
        $self->_delete();
    } elsif ( $self->{'_data'}->{'STATUS'} eq 'todisable' ) {
        $self->_disable();
    } elsif ( $self->{'_data'}->{'STATUS'} eq 'torestore' ) {
        $self->_restore();
    } else {
        die( sprintf( 'Unknown action (%s) for subdomain (ID %d)', $self->{'_data'}->{'STATUS'}, $entityId ));
    }
}

=back

=head1 PRIVATE METHODS

=over 4

=item _loadEntityData( $entityId )

 See iMSCP::Modules::Abstract::_loadEntityData()

=cut

sub _loadEntityData
{
    my ( $self, $entityId ) = @_;

    my $row = $self->{'_dbh'}->selectrow_hashref(
        "
            SELECT t1.*,
                t2.domain_name AS user_home, t2.domain_admin_id, t2.domain_mailacc_limit, t2.domain_php, t2.domain_cgi,
                t2.external_mail, t2.web_folder_protection, t2.phpini_perm_config_level AS php_config_level,
                IFNULL(t3.ip_number, '0.0.0.0') AS ip_number,
                t4.private_key, t4.certificate, t4.ca_bundle, t4.allow_hsts, t4.hsts_max_age,
                t4.hsts_include_subdomains
            FROM subdomain AS t1
            JOIN domain AS t2 USING(domain_id)
            JOIN server_ips AS t3 ON (t3.ip_id = t2.domain_ip_id)
            LEFT JOIN ssl_certs AS t4 ON(t4.domain_id = t1.subdomain_id AND t4.domain_type = 'sub' AND t4.status = 'ok')
            WHERE t1.subdomain_id = ?
        ",
        undef,
        $entityId
    );
    $row or die( sprintf( 'Data not found for subdomain (ID %d)', $entityId ));

    my $usergroup = $::imscpConfig{'SYSTEM_USER_PREFIX'} . ( $::imscpConfig{'SYSTEM_USER_MIN_UID'}+$row->{'domain_admin_id'} );
    my $homeDir = File::Spec->canonpath( "$::imscpConfig{'USER_WEB_DIR'}/$row->{'user_home'}" );
    my $webDir = File::Spec->canonpath( "$homeDir/$row->{'subdomain_mount'}" );
    my ( $ssl, $hstsMaxAge, $hstsIncSub, $phpini ) = ( FALSE, 0, '', {} );

    if ( $row->{'certificate'} && -f "$::imscpConfig{'GUI_ROOT_DIR'}/data/certs/$row->{'subdomain_name'}.$row->{'user_home'}.pem" ) {
        $ssl = TRUE;
        if ( $row->{'allow_hsts'} eq 'on' ) {
            $hstsMaxAge = $row->{'hsts_max_age'} if length $row->{'hsts_max_age'};
            $hstsIncSub = $row->{'hsts_include_subdomains'} eq 'on' ? '; includeSubDomains' : '';
        }
    }

    if ( $row->{'domain_php'} eq 'yes' ) {
        $phpini = $self->{'_dbh'}->selectrow_hashref(
            'SELECT * FROM php_ini WHERE domain_id = ? AND domain_type = ?',
            undef,
            ( $row->{'php_config_level'} eq 'per_site' ? $row->{'subdomain_id'} : $row->{'domain_id'} ),
            ( $row->{'php_config_level'} eq 'per_site' ? 'sub' : 'dmn' )
        ) || {};
    }

    $self->{'_data'} = {
        STATUS                  => $row->{'subdomain_status'},
        BASE_SERVER_VHOST       => $::imscpConfig{'BASE_SERVER_VHOST'},
        BASE_SERVER_IP          => $::imscpConfig{'BASE_SERVER_IP'},
        BASE_SERVER_PUBLIC_IP   => $::imscpConfig{'BASE_SERVER_PUBLIC_IP'},
        DOMAIN_ADMIN_ID         => $row->{'domain_admin_id'},
        ROOT_DOMAIN_ID          => $row->{'domain_id'},
        PARENT_DOMAIN_ID        => $row->{'domain_id'},
        DOMAIN_ID               => $row->{'subdomain_id'},
        ROOT_DOMAIN_NAME        => $row->{'user_home'},
        PARENT_DOMAIN_NAME      => $row->{'user_home'},
        DOMAIN_NAME             => $row->{'subdomain_name'} . '.' . $row->{'user_home'},
        DOMAIN_TYPE             => 'sub',
        DOMAIN_IP               => $::imscpConfig{'BASE_SERVER_IP'} eq '0.0.0.0' ? '0.0.0.0' : $row->{'ip_number'},
        HOME_DIR                => $homeDir,
        WEB_DIR                 => $webDir,
        MOUNT_POINT             => $row->{'subdomain_mount'},
        DOCUMENT_ROOT           => File::Spec->canonpath( "$webDir/$row->{'subdomain_document_root'}" ),
        USER                    => $usergroup,
        GROUP                   => $usergroup,
        PHP_SUPPORT             => $row->{'domain_php'},
        PHP_CONFIG_LEVEL        => $row->{'php_config_level'},
        PHP_CONFIG_LEVEL_DOMAIN => $row->{'php_config_level'} eq 'per_site'
            ? $row->{'subdomain_name'} . '.' . $row->{'user_home'} : $row->{'user_home'},
        CGI_SUPPORT             => $row->{'domain_cgi'},
        WEB_FOLDER_PROTECTION   => $row->{'web_folder_protection'},
        SSL_SUPPORT             => $ssl,
        HSTS_SUPPORT            => $ssl && $row->{'allow_hsts'} eq 'on',
        HSTS_MAX_AGE            => $hstsMaxAge,
        HSTS_INCLUDE_SUBDOMAINS => $hstsIncSub,
        ALIAS                   => 'sub' . $row->{'subdomain_id'},
        FORWARD                 => $row->{'subdomain_url_forward'} || 'no',
        FORWARD_TYPE            => $row->{'subdomain_type_forward'} || '',
        FORWARD_PRESERVE_HOST   => $row->{'subdomain_host_forward'} || 'Off',
        DISABLE_FUNCTIONS       => $phpini->{'disable_functions'} //
            'exec,passthru,phpinfo,popen,proc_open,show_source,shell,shell_exec,symlink,system',
        MAX_EXECUTION_TIME      => $phpini->{'max_execution_time'} || 30,
        MAX_INPUT_TIME          => $phpini->{'max_input_time'} || 60,
        MEMORY_LIMIT            => $phpini->{'memory_limit'} || 128,
        ERROR_REPORTING         => $phpini->{'error_reporting'} || 'E_ALL & ~E_DEPRECATED & ~E_STRICT',
        DISPLAY_ERRORS          => $phpini->{'display_errors'} || 'off',
        POST_MAX_SIZE           => $phpini->{'post_max_size'} || 8,
        UPLOAD_MAX_FILESIZE     => $phpini->{'upload_max_filesize'} || 2,
        ALLOW_URL_FOPEN         => $phpini->{'allow_url_fopen'} || 'off',
        PHP_FPM_LISTEN_PORT     => ( $phpini->{'id'} // 1 )-1,
        EXTERNAL_MAIL           => $row->{'external_mail'} eq 'on' ? TRUE : FALSE
    };
    $self->{'_data'}->{'SHARED_MOUNT_POINT'} = $self->_sharedMountPoint();
}

=item _add()

 See iMSCP::Modules::Abstract::_add()

=cut

sub _add
{
    my ( $self ) = @_;

    eval { $self->SUPER::_add(); };
    $self->{'_dbh'}->do( 'UPDATE subdomain SET subdomain_status = ? WHERE subdomain_id = ?', undef, $@ || 'ok', $self->{'_data'}->{'DOMAIN_ID'} );
}

=item _delete()

 See iMSCP::Modules::Abstract::_delete()

=cut

sub _delete
{
    my ( $self ) = @_;

    eval { $self->SUPER::_delete(); };
    if ( $@ ) {
        $self->{'_dbh'}->do( 'UPDATE subdomain SET subdomain_status = ? WHERE subdomain_id = ?', undef, $@, $self->{'_data'}->{'DOMAIN_ID'} );
        return $self;
    }

    $self->{'_dbh'}->do( 'DELETE FROM subdomain WHERE subdomain_id = ?', undef, $self->{'_data'}->{'DOMAIN_ID'} );
}

=item _disable()

 See iMSCP::Modules::Abstract::_disable()

=cut

sub _disable
{
    my ( $self ) = @_;

    eval { $self->SUPER::_disable(); };
    $self->{'_dbh'}->do(
        'UPDATE subdomain SET subdomain_status = ? WHERE subdomain_id = ?', undef, $@ || 'disabled', $self->{'_data'}->{'DOMAIN_ID'}
    );
}

=item _restore()

 See iMSCP::Modules::Abstract::_restore()

=cut

sub _restore
{
    my ( $self ) = @_;

    eval { $self->SUPER::_restore(); };
    $self->{'_dbh'}->do( 'UPDATE subdomain SET subdomain_status = ? WHERE subdomain_id = ?', undef, $@ || 'ok', $self->{'_data'}->{'DOMAIN_ID'} );
}

=item _sharedMountPoint( )

 Is the subdomain sharing a mount point with another domain?

 Return bool TRUE if the subdomain share a mount point with another domain, FALSE otherwise, die on failure

=cut

sub _sharedMountPoint
{
    my ( $self ) = @_;

    my $regexp = "^$self->{'_data'}->{'MOUNT_POINT'}(/.*|\$)";
    my ( $nbSharedMountPoints ) = $self->{'_dbh'}->selectrow_array(
        "
            SELECT COUNT(mount_point) AS nb_mount_points FROM (
                SELECT alias_mount AS mount_point FROM domain_aliasses
                WHERE domain_id = ? AND alias_status NOT IN ('todelete', 'ordered') AND alias_mount RLIKE ?
                UNION ALL
                SELECT subdomain_mount AS mount_point FROM subdomain
                WHERE subdomain_id <> ? AND domain_id = ? AND subdomain_status <> 'todelete' AND subdomain_mount RLIKE ?
                UNION ALL
                SELECT subdomain_alias_mount AS mount_point FROM subdomain_alias
                WHERE subdomain_alias_status <> 'todelete'
                AND alias_id IN (SELECT alias_id FROM domain_aliasses WHERE domain_id = ?)
                AND subdomain_alias_mount RLIKE ?
            ) AS tmp
        ",
        undef,
        $self->{'_data'}->{'PARENT_DOMAIN_ID'},
        $regexp,
        $self->{'_data'}->{'DOMAIN_ID'},
        $self->{'_data'}->{'PARENT_DOMAIN_ID'},
        $regexp,
        $self->{'_data'}->{'PARENT_DOMAIN_ID'},
        $regexp
    );
    $nbSharedMountPoints || $self->{'_data'}->{'MOUNT_POINT'} eq '/';
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
