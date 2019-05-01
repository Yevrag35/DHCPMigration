# DHCP Migration
[![version](https://img.shields.io/powershellgallery/v/DHCPMigration.svg)](https://www.powershellgallery.com/packages/DHCPMigration)
[![downloads](https://img.shields.io/powershellgallery/dt/DHCPMigration.svg?label=downloads)](https://www.powershellgallery.com/stats/packages/DHCPMigration?groupby=Version)

This module is intended to help sysadmins in the process of migrating 'pre-failover capable' DHCP servers.  It has the ability to copy all sorts of information from one server to another:

1. Leases
1. Policies
1. Reservations
1. Scopes
1. Scope Options
1. Server Option Definitions
1. Server Option Values

Each function can also be provided with PSCredentials to one or both servers, as well as providing already established CimSessions.

## The commands:

### [Copy-DhcpLease](https://github.com/Yevrag35/DHCPMigration/wiki/Copy-DhcpLease)
### [Copy-DhcpPolicy](https://github.com/Yevrag35/DHCPMigration/wiki/Copy-DhcpPolicy)
### [Copy-DhcpScope](https://github.com/Yevrag35/DHCPMigration/wiki/Copy-DhcpScope)
### [Copy-DhcpServerOptionDefinition](https://github.com/Yevrag35/DHCPMigration/wiki/Copy-DhcpServerOptionDefinition)
### [Copy-DhcpServerOptionValue](https://github.com/Yevrag35/DHCPMigration/wiki/Copy-DhcpServerOptionValue)

** NOTE ** -
This module only deals with __IPv4__ information; IPv6 is not supported.