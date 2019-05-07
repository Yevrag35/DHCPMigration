#region MODULE FUNCTIONS
Function Copy-DhcpServerOptionDefinition()
{
    <#
        .EXTERNALHELP en-US\DHCPMigration.psm1-Help.xml
    #>
    [CmdletBinding(SupportsShouldProcess=$true, PositionalBinding=$false,
        DefaultParameterSetName='ByCredential')]
    [alias("copyoptdefs")]
    param
    (
        [parameter(Mandatory=$false, Position=0, ParameterSetName='ByCredential')]
        [alias("t", "to")]
        [string] $ToServer = $env:COMPUTERNAME,

        [parameter(Mandatory=$true, Position=1, ParameterSetName='ByCredential')]
        [alias("f", "from")]
        [string] $FromServer,

        [parameter(Mandatory=$false, Position=2)]
        [alias("id")]
        [int[]] $OptionId,

        [parameter(Mandatory=$false, ParameterSetName='ByCredential')]
        [alias("toc")]
        [pscredential] $ToCredential,

        [parameter(Mandatory=$false, ParameterSetName='ByCredential')]
        [alias("froc")]
        [pscredential] $FromCredential,

        [parameter(Mandatory=$false, Position=0, ParameterSetName='ByCimSession')]
        [alias("tcim")]
        [Microsoft.Management.Infrastructure.CimSession] $ToCimSession,
        
        [parameter(Mandatory=$false, Position=1, ParameterSetName='ByCimSession')]
        [alias("fcim")]
        [Microsoft.Management.Infrastructure.CimSession] $FromCimSession
    )
    Begin
    {
        $private:bank = PrepareConnections -SetName $PSCmdlet.ParameterSetName -BoundParameters $PSBoundParameters;
        $to = $private:bank.To;
        $from = $private:bank.From;
        if ($PSBoundParameters.ContainsKey("Confirm"))
        {
            $to.Confirm = $PSBoundParameters["Confirm"];
        }
        else
        {
            $to.Confirm = $true;
        }
        if ($PSBoundParameters.ContainsKey("Verbose"))
        {
            $to.Verbose = $PSBoundParameters["Verbose"];
        }
    }
    Process
    {
        Write-Verbose "Gathering options from source server...";
        $oldDefs = Get-DhcpServerv4OptionDefinition @from -All;
        Write-Verbose "Gathering options from destination server...";
        $newDefs = Get-DhcpServerv4OptionDefinition @to -All;
        $compareArgs = @{
            ReferenceObject  = $oldDefs	    # Source Option Definitions
            DifferenceObject = $newDefs	    # Option Definitions from the destination server
            Property         = "OptionId"
        };

        Write-Verbose "Comparing OptionId differences...";
        $differences = @(Compare-Object @compareArgs | Where-Object { $_.SideIndicator -eq '<=' } | Select-Object -ExpandProperty OptionId);
        if ($PSBoundParameters.ContainsKey("OptionId"))
        {
            $differences = $differences | Where-Object { $_ -in $OptionId }
        }
        Write-Verbose $("There are {0} differences to be copied over." -f $differences.Count);
        if ($differences.Count -gt 0)
        {
            foreach ($def in $differences)
            {
                $opt = $oldDefs | Where-Object { $_.OptionId -eq $def };
                $optArgs = @{
                    Name         = $opt.Name
                    OptionId     = $opt.OptionId
                    Description  = $opt.Description
                    Type         = $opt.Type
                    MultiValued  = $opt.MultiValued
                    VendorClass  = $opt.VendorClass
                    DefaultValue = $opt.DefaultValue
                    Confirm      = switch ($PSBoundParameters.ContainsKey("Confirm")) { $true { $PSBoundParameters["Confirm"] } $false { $true } }
                    WhatIf       = $PSBoundParameters.ContainsKey("WhatIf")
                };
                Write-Verbose $("Executing `"Add-DhcpServerv4OptionDefinition`" on destination server for OptionId {0}..." -f $opt.OptionId);
                Write-Debug $("Add-DhcpServerv4OptionDefinition arguments:`n`n{0}" -f $($optArgs | Out-String));
                Add-DhcpServerv4OptionDefinition @to @optArgs;
            }
        }
        else
        {
            Write-Verbose "All options are present on the destination DHCP server.";
        }
    }
}

Function Copy-DhcpServerOptionValue()
{
    <#
        .EXTERNALHELP en-US\DHCPMigration.psm1-Help.xml
    #>
    [CmdletBinding(SupportsShouldProcess=$true, PositionalBinding=$false,
        DefaultParameterSetName='ByCredential')]
    [alias("copyoptvals")]
    param
    (
        [parameter(Mandatory=$false, Position=0, ParameterSetName='ByCredential')]
        [alias("t", "to")]
        [string] $ToServer = $env:COMPUTERNAME,

        [parameter(Mandatory=$true, Position=1, ParameterSetName='ByCredential')]
        [alias("f", "from")]
        [string] $FromServer,

        [parameter(Mandatory=$false, Position=2)]
        [alias("id")]
        [int[]] $OptionId,

        [parameter(Mandatory=$false)]
        [switch] $OverwriteExisting,

        [parameter(Mandatory=$false, ParameterSetName='ByCredential')]
        [alias("toc")]
        [pscredential] $ToCredential,

        [parameter(Mandatory=$false, ParameterSetName='ByCredential')]
        [alias("froc")]
        [pscredential] $FromCredential,

        [parameter(Mandatory=$false, Position=0, ParameterSetName='ByCimSession')]
        [alias("tcim")]
        [Microsoft.Management.Infrastructure.CimSession] $ToCimSession,
        
        [parameter(Mandatory=$false, Position=1, ParameterSetName='ByCimSession')]
        [alias("fcim")]
        [Microsoft.Management.Infrastructure.CimSession] $FromCimSession
    )
    Begin
    {
        $private:bank = PrepareConnections -SetName $PSCmdlet.ParameterSetName -BoundParameters $PSBoundParameters;
        $to = $private:bank.To;
        $from = $private:bank.From;
        if ($PSBoundParameters.ContainsKey("Confirm"))
        {
            $to.Confirm = $PSBoundParameters["Confirm"];
        }
        else
        {
            $to.Confirm = $true;
        }
        if ($PSBoundParameters.ContainsKey("Verbose"))
        {
            $to.Verbose = $PSBoundParameters["Verbose"];
        }
    }
    Process
    {
        $oldVals = @(Get-DhcpServerv4OptionValue @from -All);
        if ($PSBoundParameters.ContainsKey("OptionId"))
        {
            $oldVals = $oldVals | Where-Object { $_.OptionId -in $OptionId };
        }
        $from.Remove("ErrorAction");
        foreach ($val in $oldVals)
        {
            if ($PSBoundParameters.ContainsKey("OverwriteExisting") -or $($null -eq $(Get-DhcpServerv4OptionValue @to -OptionId $val.OptionId -ErrorAction SilentlyContinue)))
            {
                Set-DhcpServerv4OptionValue @to -OptionId $val.OptionId -Value $val.Value;
            }
        }
    }
}

Function Copy-DhcpPolicy()
{
    <#
        .EXTERNALHELP en-US\DHCPMigration.psm1-Help.xml
    #>
    [CmdletBinding(SupportsShouldProcess=$true, PositionalBinding=$false,
        DefaultParameterSetName='ServerPoliciesByCredential')]
    param
    (
        [parameter(Mandatory=$false, Position=0, ParameterSetName='ServerPoliciesByCredential')]
        [parameter(Mandatory=$false, Position=0, ParameterSetName='ScopePoliciesByCredential')]
        [alias("t", "to")]
        [string] $ToServer = $env:COMPUTERNAME,

        [parameter(Mandatory=$true, Position=1, ParameterSetName='ServerPoliciesByCredential')]
        [parameter(Mandatory=$true, Position=1, ParameterSetName='ScopePoliciesByCredential')]
        [alias("f", "from")]
        [string] $FromServer,

        [parameter(Mandatory=$false, Position=2)]
        [alias("name")]
        [string[]] $PolicyName,

        [parameter(Mandatory=$true, ParameterSetName='ScopePoliciesByCredential')]
        [parameter(Mandatory=$true, ParameterSetName='ScopePoliciesByCimSession')]
        [ipaddress] $ToScopeId,

        [parameter(Mandatory=$true, ParameterSetName='ScopePoliciesByCredential')]
        [parameter(Mandatory=$true, ParameterSetName='ScopePoliciesByCimSession')]
        [ipaddress] $FromScopeId,

        [parameter(Mandatory=$false, ParameterSetName='ServerPoliciesByCredential')]
        [parameter(Mandatory=$false, ParameterSetName='ScopePoliciesByCredential')]
        [alias("toc")]
        [pscredential] $ToCredential,

        [parameter(Mandatory=$false, ParameterSetName='ServerPoliciesByCredential')]
        [parameter(Mandatory=$false, ParameterSetName='ScopePoliciesByCredential')]
        [alias("froc")]
        [pscredential] $FromCredential,

        [parameter(Mandatory=$false, Position=0, ParameterSetName='ServerPoliciesByCimSession')]
        [parameter(Mandatory=$false, Position=0, ParameterSetName='ScopePoliciesByCimSession')]
        [alias("tcim")]
        [Microsoft.Management.Infrastructure.CimSession] $ToCimSession,
        
        [parameter(Mandatory=$false, Position=1, ParameterSetName='ServerPoliciesByCimSession')]
        [parameter(Mandatory=$false, Position=0, ParameterSetName='ScopePoliciesByCimSession')]
        [alias("fcim")]
        [Microsoft.Management.Infrastructure.CimSession] $FromCimSession
    )
    Begin
    {
        $private:bank = PrepareConnections -SetName $PSCmdlet.ParameterSetName -BoundParameters $PSBoundParameters;
        $to = $private:bank.To;
        $from = $private:bank.From;

        if ($PSCmdlet.ParameterSetName -in @("ScopePoliciesByCredential", "ScopePoliciesByCimSession"))
        {
            $to.ScopeId = $PSBoundParameters["ToScopeId"];
            $from.ScopeId = $PSBoundParameters["FromScopeId"];
        }
        if ($PSBoundParameters.ContainsKey("Verbose"))
        {
            $to.Verbose = $PSBoundParameters["Verbose"];
        }
    }
    Process
    {
        $allPolicies = @(Get-DhcpServerv4Policy @from);
        if ($PSBoundParameters.ContainsKey("PolicyName"))
        {
            $allPolicies = $allPolicies | Where-Object { $_.Name -in $PolicyName };
        }
        if ($allPolicies.Count -le 0)
        {
            return;
        }
        $properties = $allPolicies[0] | Get-Member -MemberType Property | Where-Object { $_.Name -ne "PSComuputerName" } | Select-Object -ExpandProperty Name;

        if ($PSBoundParameters.ContainsKey("Confirm"))
        {
            $to.Confirm = $PSBoundParameters["Confirm"];
        }
        else
        {
            $to.Confirm = $true;
        }
        foreach ($p in $allPolicies)
        {
            $hash = @{};
            foreach ($prop in $properties)
            {
                if (($p.$prop -is [string] -and ([string]::IsNullOrEmpty($p.$prop) -or $p.$prop -eq "0.0.0.0")) -or ($p.$prop -isnot [string] -and $null -eq $p.$prop) -or ($p.$prop -is [timespan] -and $p.$prop.Ticks -eq 0))
                {
                    continue;
                }
                $hash.Add($prop, $p.$prop);
            }
            Add-DhcpServerv4Policy @to @hash;
        }
    }
}

Function Copy-DhcpScope()
{
    <#
        .EXTERNALHELP en-US\DHCPMigration.psm1-Help.xml
    #>
    [CmdletBinding(SupportsShouldProcess=$true, PositionalBinding=$false,
        DefaultParameterSetName='ByCredential')]
    param
    (
        [parameter(Mandatory=$false, Position=0, ParameterSetName='ByCredential')]
        [alias("t", "to")]
        [string] $ToServer = $env:COMPUTERNAME,

        [parameter(Mandatory=$true, Position=1, ParameterSetName='ByCredential')]
        [alias("f", "from")]
        [string] $FromServer,

        [parameter(Mandatory=$false, Position=2)]
        [alias("sid")]
        [ipaddress[]] $ScopeId,

        [parameter(Mandatory=$false)]
        [switch] $ExcludeScopeOptions,

        [parameter(Mandatory=$false, ParameterSetName='ByCredential')]
        [alias("toc")]
        [pscredential] $ToCredential,

        [parameter(Mandatory=$false, ParameterSetName='ByCredential')]
        [alias("froc")]
        [pscredential] $FromCredential,

        [parameter(Mandatory=$false, Position=0, ParameterSetName='ByCimSession')]
        [alias("tcim")]
        [Microsoft.Management.Infrastructure.CimSession] $ToCimSession,
        
        [parameter(Mandatory=$false, Position=1, ParameterSetName='ByCimSession')]
        [alias("fcim")]
        [Microsoft.Management.Infrastructure.CimSession] $FromCimSession
    )
    Begin
    {
        Write-Verbose "Preparing connections..."
        $private:bank = PrepareConnections -SetName $PSCmdlet.ParameterSetName -BoundParameters $PSBoundParameters;
        $to = $private:bank.To;
        $from = $private:bank.From;

        if ($PSBoundParameters.ContainsKey("Verbose"))
        {
            $to.Verbose = $PSBoundParameters["Verbose"];
        }
        Write-Debug "To Hash: $($to | Out-String)";
        Write-Debug "From Hash: $($from | Out-String)";
    }
    Process
    {
        if ($PSBoundParameters.ContainsKey("ScopeId"))
        {
            $allScopes = @(Get-DhcpServerv4Scope @from -ScopeId $ScopeId);
        }
        else
        {
            $allScopes = @(Get-DhcpServerv4Scope @from);
        }

        if ($PSBoundParameters.ContainsKey("Confirm"))
        {
            $to.Confirm = $PSBoundParameters["Confirm"];
        }
        else
        {
            $to.Confirm = $true;
        }
        for ($i = 1; $i -le $allScopes.Count; $i++)
        {
            $scope = $allScopes[$i - 1];
            Write-ScriptProgress -Activity "Scopes" -Id 1 -Total $allScopes.Count -On $i;

            $addScopeArgs = @{
                Name             = $scope.Name
                SubnetMask       = $scope.SubnetMask
                StartRange       = $scope.StartRange
                EndRange         = $scope.EndRange
                State            = "Inactive"            # We will mark the newly created scope as 'Inactive'.
                Description      = $scope.Description
                SuperscopeName   = $scope.SuperscopeNames
                MaxBootpClients  = $scope.MaxBootpClients
                Type             = $scope.Type
                ActivatePolicies = $scope.ActivatePolicies
                Delay            = $scope.Delay
                LeaseDuration    = $scope.LeaseDuration
                NapEnable        = $scope.NapEnable
                NapProfile       = $scope.NapProfile
            };

            Write-Debug "Scope Args: $($addScopeArgs | Out-String)";
            Add-DhcpServerv4Scope @to @addScopeArgs;

            if (-not $PSBoundParameters.ContainsKey("ExcludeScopeOptions"))
            {
                $optVals = @(Get-DhcpServerv4OptionValue @from -ScopeId $scope.ScopeId -All);
                if ($optVals.Count -gt 0)
                {
                    foreach ($val in $optVals)
                    {
                        Set-DhcpServerv4OptionValue @to -ScopeId $scope.ScopeId -OptionId $val.OptionId -Value $val.Value;
                    }
                }
            }
        }
        Write-ScriptProgress -Activity "Scopes" -Id 1 -Completed;
    }
}

Function Copy-DhcpLease()
{
    <#
        .EXTERNALHELP en-US\DHCPMigration.psm1-Help.xml
    #>
    [CmdletBinding(SupportsShouldProcess=$true, PositionalBinding=$false,
        DefaultParameterSetName='ByCredential')]
    param
    (
        [parameter(Mandatory=$false, Position=1, ParameterSetName='ByCredential')]
        [alias("t", "to")]
        [string] $ToServer = $env:COMPUTERNAME,

        [parameter(Mandatory=$true, Position=0, ParameterSetName='ByCredential')]
        [alias("f", "from")]
        [string] $FromServer,

        [parameter(Mandatory=$false, Position=2)]
        [alias("sid")]
        [ipaddress[]] $ScopeId,

        [parameter(Mandatory=$false)]
        [switch] $ExcludeReservations,

        [parameter(Mandatory=$false, ParameterSetName='ByCredential')]
        [alias("toc")]
        [pscredential] $ToCredential,

        [parameter(Mandatory=$false, ParameterSetName='ByCredential')]
        [alias("froc")]
        [pscredential] $FromCredential,

        [parameter(Mandatory=$false, Position=0, ParameterSetName='ByCimSession')]
        [alias("tcim")]
        [Microsoft.Management.Infrastructure.CimSession] $ToCimSession,
        
        [parameter(Mandatory=$false, Position=1, ParameterSetName='ByCimSession')]
        [alias("fcim")]
        [Microsoft.Management.Infrastructure.CimSession] $FromCimSession
    )
    Begin
    {
        Write-Verbose "Preparing connections..."
        $private:bank = PrepareConnections -SetName $PSCmdlet.ParameterSetName -BoundParameters $PSBoundParameters;
        $to = $private:bank.To;
        $from = $private:bank.From;

        if ($PSBoundParameters.ContainsKey("Verbose"))
        {
            $to.Verbose = $PSBoundParameters["Verbose"];
        }
        Write-Debug "To Hash: $($to | Out-String)";
        Write-Debug "From Hash: $($from | Out-String)";
    }
    Process
    {
        if ($PSBoundParameters.ContainsKey("ScopeId"))
        {
            $sids = $ScopeId.ForEach({$_.ToString()}) -join ', ';
            Write-Verbose "Retrieving leases from $sids..."
            $allLeases = @(Get-DhcpServerv4Scope @from -ScopeId $ScopeId | Get-DhcpServerv4Lease @from);
        }
        else
        {
            Write-Verbose "Retrieving all scope leases...";
            $allLeases = @(Get-DhcpServerv4Scope @from | Get-DhcpServerv4Lease @from);
        }
        $leases = @($allLeases | Where-Object { $_.AddressState -notlike "*Reservation" });
        Write-Progress -Activity "Lease Copy" -Status "Running steps 1/2..." -Id 1 -PercentComplete 50;

        if ($PSBoundParameters.ContainsKey("Confirm"))
        {
            $to.Confirm = $PSBoundParameters["Confirm"];
        }
        else
        {
            $to.Confirm = $true;
        }
        for ($i = 1; $i -le $leases.Count; $i++)
        {
            $lease = $leases[$i - 1];
            Write-ScriptProgress -Activity "Leases" -Id 2 -Total $leases.Count -On $i;

            $leaseArgs = @{
                ScopeId = $lease.ScopeId
                IPAddress = $lease.IPAddress
                AddressState = $lease.AddressState
                HostName = $lease.HostName
                Description = $lease.Description
                DnsRR = $lease.DnsRR
                DnsRegistration = $lease.DnsRegistration
                ClientType = $lease.ClientType
                LeaseExpiryTime = $lease.LeaseExpiryTime
                NapCapable = $lease.NapCapable
                NapStatus = $lease.NapStatus
                ProbationEnds = $lease.ProbationEnds
                ClientId = $lease.ClientId
            };
            Write-Debug "Lease Args: $($leaseArgs | Out-String)";
            Add-DhcpServerv4Lease @to @leaseArgs;
        }
        Write-ScriptProgress -Activity "Leases" -Id 2 -Completed;

        Write-Progress -Activity "Lease Copy" -Status "Running step 2/2..." -Id 1 -PercentComplete 75;
        if (-not $PSBoundParameters.ContainsKey("ExcludeReservations"))
        {
            Write-Verbose "Now creating any reservations...";
            $resrv = @($allLeases | Where-Object { $_.AddressState -like "*Reservation" });
            for ($r = 1; $r -le $resrv.Count; $r++)
            {
                $res = $resrv[$r - 1];
                Write-ScriptProgress -Activity "Reservations" -Id 3 -Total $resrv.Count -On $r;

                $resArgs = @{
                    ScopeId = $res.ScopeId
                    IPAddress = $res.IPAddress
                    ClientId = $res.ClientId
                    Name = $res.Name
                    Description = $res.Description
                    Type = $res.Type
                };
                Write-Debug "Reservation Args: $($resArgs | Out-String)";
                Add-DhcpServerv4Reservation @to @resArgs;
            }
            Write-ScriptProgress -Activity "Reservations" -Id 3 -Completed;
        }
        Write-Progress -Activity "Lease Copy" -Id 1 -Completed;
    }
}


#endregion

#region BACKEND FUNCTIONS
Function PrepareConnections([string]$SetName, [System.Collections.IDictionary]$BoundParameters)
{
    $private:toHash = @{}
    if ($BoundParameters.ContainsKey("ErrorAction"))
    {
        $private:toHash.ErrorAction = $BoundParameters["ErrorAction"];
    }
    if ($BoundParameters.ContainsKey("Verbose"))
    {
        $private:toHash.Verbose = $true;
    }
    # if ($BoundParameters.ContainsKey("Debug"))
    # {
    #     $private:toHash.Debug = $true;
    # }
    $private:fromHash = $private:toHash.Clone();

    if ($SetName -eq "ByCredential")
    {
        if ($BoundParameters.ContainsKey("ToCredential"))
        {
            $private:toHash.CimSession = New-CimSession  -ComputerName $BoundParameters["ToServer"] -Credential $BoundParameters["ToCredential"];
        }
        else
        {
            $private:toHash.ComputerName = switch ($BoundParameters.ContainsKey("ToServer")) { $true { $BoundParameters["ToServer"] } $false { $env:COMPUTERNAME } }
        }
        if ($BoundParameters.ContainsKey("FromCredential"))
        {
            $private:fromHash.CimSession = New-CimSession -ComputerName $BoundParameters["FromServer"] -Credential $BoundParameters["FromCredential"];
        }
        else
        {
            $private:fromHash.ComputerName = $BoundParameters["FromServer"];
        }
    }
    else
    {
        if ($BoundParameters.ContainsKey("ToCimSession"))
        {
            $private:toHash.CimSession = $BoundParameters["ToCimSession"];
        }
        if ($BoundParameters.ContainsKey("FromCimSession"))
        {
            $private:fromHash.CimSession = $BoundParameters["FromCimSession"];
        }
    }
    
    $private:combined = [pscustomobject]@{
        To = $private:toHash
        From = $private:fromHash
    };
    Write-Output $private:combined -NoEnumerate;
}

Function Write-ScriptProgress()
{
    [CmdletBinding(PositionalBinding = $false, DefaultParameterSetName = "StillRunning")]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateSet("Scopes", "Options", "Reservations", "Leases")]
        [string] $Activity,

        [parameter(Mandatory = $true)]
        [int] $Id,

        [parameter(Mandatory = $true, ParameterSetName = "StillRunning")]
        [int] $On,

        [parameter(Mandatory = $true, ParameterSetName = "StillRunning")]
        [int] $Total,

        [parameter(Mandatory = $true, ParameterSetName = "Complete")]
        [switch] $Completed
    )
    $splat = @{
        Id       = $Id
        Activity = "Adding $Activity"
    };

    if (-not $PSBoundParameters.ContainsKey("Completed"))
    {
        if ($Id -ne 1)
        {
            $splat.ParentId = 1;
        }

        switch ($Activity)
        {
            "Scopes"
            {
                $Status = "Copying Scope {0}/{1}...";
            }
            "Options"
            {
                $Status = "Copying Scope Option {0}/{1}...";
            }
            "Reservations"
            {
                $Status = "Copying Reservation {0}/{1}...";
            }
            "Leases"
            {
                $Status = "Copying Lease {0}/{1}..."
            }
        }
        $splat.Status = $Status -f $On, $Total;
        $splat.PercentComplete = (($On / $Total) * 100);
    }
    else
    {
        $splat.Completed = $true
    }
    Write-Progress @splat;
}

#endregion