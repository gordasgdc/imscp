# i-MSCP iMSCP::Listener::Postfix::Transport::Table listener file
# Copyright (C) 2017-2018 Laurent Declercq <l.declercq@nuxwin.com>
# Copyright (C) 2017 Matthew L. Hill <m.hill@innodapt.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA

package iMSCP::Listener::Postfix::Transport::Table;

#
## Allows to add entries in the postfix transport(5) table
#

our $VERSION = '1.0.1';

use strict;
use warnings;
use iMSCP::EventManager;
use iMSCP::Servers::Mta;

#
## Configuration variables
#

# Parameter that allows to specify transport entries that must be added in the
# Postfix transport(5) table.
#
# Please replace the entries below by your own entries.
my %transportTableEntries = (
    'recipientdomain.tld' => 'relay:my.smtprelay',
    'user2@domain.tld'    => 'smtp:some-other-host'
);

#
## Please, don't edit anything below this line
#

# Listener responsible to add entries in the Postfix transport(5) table
iMSCP::EventManager->getInstance()->register(
    'afterPostfixConfigure',
    sub {
        my $dbDriver = iMSCP::Servers::Mta->factory()->getDbDriver();
        while ( my ($recipient, $transport) = each( %transportTableEntries ) ) {
            $dbDriver->add( 'transport_maps', $recipient, $transport );
        }
    }
) if index( $::imscpConfig{'iMSCP::Servers::Mta'}, '::Postfix::' ) != -1;

1;
__END__
