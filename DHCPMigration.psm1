#region MODULE FUNCTIONS
Function Copy-DhcpServerClass()
{
    <#
        .EXTERNALHELP en-US\DHCPMigration.psm1-Help.xml
    #>
    [CmdletBinding(SupportsShouldProcess = $true, PositionalBinding = $false, DefaultParameterSetName = "ByCredential")]
    [alias("copyclasses")]
    param
    (
        [parameter(Mandatory=$false, Position=0, ParameterSetName='ByCredential')]
        [alias("t", "to")]
        [string] $ToServer = $env:COMPUTERNAME,

        [parameter(Mandatory=$true, Position=1, ParameterSetName='ByCredential')]
        [alias("f", "from")]
        [string] $FromServer,

        [parameter(Mandatory=$false)]
        [SupportsWildcards]
        [string[]] $ClassName,

        [parameter(Mandatory=$false)]
        [ValidateSet("User", "Vendor")]
        [string[]] $Type = [string[]]@("User", "Vendor"),

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
        $private:bank = PrepareConnections -SetName $PSCmdlet.ParameterSetName -BoundParameters $PSCmdlet.MyInvocation.BoundParameters;
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
        $getArgs = $from.Clone();
        if ($PSBoundParameters.ContainsKey("Type") -and -not $Type.Length -ne 2)
        {
            $getArgs.Add("Type", $Type[0]);
        }
        Write-Debug "Get Args: $($getArgs | Out-String)";
        $allFromClasses = @(Get-DhcpServerv4Class @getArgs);
        $list = New-Object -TypeName 'System.Collections.Generic.List[object]' $allFromClasses.Count;
        if ($PSBoundParameters.ContainsKey("ClassName"))
        {
            for ($n = 0; $n -lt $ClassName.Length; $n++)
            {
                $wcp = New-Object WildcardPattern($ClassName[$n], [System.Management.Automation.WildcardOptions]::IgnoreCase);
                for ($i = 0; $i -lt $allFromClasses.Count; $i++)
                {
                    $fromCls = $allFromClasses[$i];
                    if ($wcp.IsMatch($fromCls.Name))
                    {
                        $list.Add($fromCls) > $null;
                    }
                }
            }
        }
        else
        {
            $list.AddRange($allFromClasses);
        }

        $allToClasses = @(Get-DhcpServerv4Class @to);
        for ($p = 0; $p -lt $allToClasses.Count; $p++)
        {
            $toCls = $allToClasses[$p];
            for ($r = $list.Count - 1; $r -ge 0; $r--)
            {
                $listCls = $list[$r];
                if ($toCls.Name -eq $listCls.Name)
                {
                    $list.Remove($listCls) > $null;
                }
            }
        }
    }
    End
    {
        for ($v = 1; $v -le $list.Count; $v++)
        {
            $copyCls = $list[$v-1];
            Write-ScriptProgress -Activity "Classes" -Id 0 -On $v -Total $list.Count;
            $newClassArgs = @{
                Name = $copyCls.Name
                Type = $copyCls.Type
                Data = $copyCls.Data
                Description = $copyCls.Description
            }
            Add-DhcpServerv4Class @newClassArgs @to;
        }
        Write-ScriptProgress -Activity Classes -Id 0 -Completed;
    }
}

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
                #Write-Verbose $("Executing `"Add-DhcpServerv4OptionDefinition`" on destination server for OptionId {0}..." -f $opt.OptionId);
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
        $confirmArgs = @{}
        if ($PSBoundParameters.ContainsKey("Confirm"))
        {
            $confirmArgs.Confirm = $PSBoundParameters["Confirm"];
        }
        else
        {
            $confirmArgs.Confirm = $true;
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
            if ($null -ne $(Get-DhcpServerv4OptionDefinition @to -OptionId $val.OptionId -ErrorAction SilentlyContinue))
            {
                if ($PSBoundParameters.ContainsKey("OverwriteExisting") -or $($null -eq $(Get-DhcpServerv4OptionValue @to -OptionId $val.OptionId -ErrorAction SilentlyContinue)))
                {
                    Set-DhcpServerv4OptionValue @to -OptionId $val.OptionId -Value $val.Value @confirmArgs -ErrorAction Stop;
                }
                else
                {
                    Write-Warning $("Option {0} has an existing value set. Use the '-OverwriteExisting' switch to override." -f $val.OptionId);
                }
            }
            else
            {
                Write-Warning $("Option {0} does NOT exist on destination. Skipping value set." -f $val.OptionId);
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
        [switch] $CopyStateAsIs,

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
        $scopeArgs = @{}
        if ($PSBoundParameters.ContainsKey("ScopeId"))
        {
            $scopeArgs.ScopeId = $ScopeId;
        }
        $allScopes = @(Get-DhcpServerv4Scope @from @scopeArgs);
        $confirmArgs = @{}
        if ($PSBoundParameters.ContainsKey("Confirm"))
        {
            $confirmArgs.Confirm = $PSBoundParameters["Confirm"];
        }
        else
        {
            $confirmArgs.Confirm = $true;
        }
        $needDns = $null -eq $(Get-DhcpServerv4OptionValue @to -OptionId 6 -ErrorAction SilentlyContinue);
        $needRouter = $null -eq $(Get-DhcpServerv4OptionValue @to -OptionId 3 -ErrorAction SilentlyContinue);
        for ($i = 1; $i -le $allScopes.Count; $i++)
        {
            $scope = $allScopes[$i - 1];
            Write-ScriptProgress -Activity "Scopes" -Id 1 -Total $allScopes.Count -On $i;

            $addScopeArgs = @{
                Name             = $scope.Name
                SubnetMask       = $scope.SubnetMask
                StartRange       = $scope.StartRange
                EndRange         = $scope.EndRange
                #State            = "Inactive"            # We will mark the newly created scope as 'Inactive'.
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

            if ($PSBoundParameters.ContainsKey("RetainStatus"))
            {
                $addScopeArgs.State = $scope.State;
            }
            else
            {
                $addScopeArgs.State = "Inactive";
            }

            Write-Debug "Scope Args: $($addScopeArgs | Out-String)";
            try
            {
                Add-DhcpServerv4Scope @to @addScopeArgs @confirmArgs -ErrorAction Stop;
            }
            catch [Microsoft.Management.Infrastructure.CimException]
            {
                $ex = $_.Exception;
                if ($ex.NativeErrorCode -eq "AlreadyExists")
                {
                    Write-Warning $("Skipping scope creation for '{0}' as it already exists on the destination server." -f $scope.ScopeId.ToString());
                }
            }
            catch
            {
                throw $_.Exception.Message;
            }

            if (-not $PSBoundParameters.ContainsKey("ExcludeScopeOptions"))
            {
                $hasDns = $false;
                $hasRouter = $false;
                $optVals = @(Get-DhcpServerv4OptionValue @from -ScopeId $scope.ScopeId -All);
                if ($optVals.Count -gt 0)
                {
                    foreach ($val in $optVals)
                    {
                        if ($val.OptionId -eq 6)
                        {
                            $hasDns = $true;
                        }
                        elseif ($val.OptionId -eq 3)
                        {
                            $hasRouter = $true;
                        }
                        try
                        {
                            Set-DhcpServerv4OptionValue @to -ScopeId $scope.ScopeId -OptionId $val.OptionId -Value $val.Value @confirmArgs -ErrorAction Stop;
                        }
                        catch [Microsoft.Management.Infrastructure.CimException]
                        {
                            $ex = $_.Exception;
                            if ($ex.NativeErrorCode -eq "NotFound")
                            {
                                throw $("Option {0} does NOT exist on destination. Run 'Copy-DhcpServerOptionDefinitions' to fix this." -f $val.OptionId);
                            }
                        }
                    }
                }
                # Check for Option 3 and warn if not present in scope or server options.
                if ($needRouter -and -not $hasRouter)
                {
                    Write-Warning $("Scope '{0}' does not have Option 3 (Router) set for the scope or on the server!" -f $scope.ScopeId);
                }

                # Check for Option 6 and Warn if not present in scope or server options.
                if ($needDns -and -not $hasDns)
                {
                    Write-Warning $("Scope '{0}' does not have Option 6 (DNS Servers) set for the scope or on the server!" -f $scope.ScopeId);
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
        $scopeArgs=@{}
        if ($PSBoundParameters.ContainsKey("ScopeId"))
        {
            $sids = $ScopeId.ForEach({$_.ToString()}) -join ', ';
            Write-Verbose "Retrieving leases from $sids..."
            $scopeArgs.ScopeId = $sids;
        }
        else
        {
            Write-Verbose "Retrieving all scope leases...";
        }
        $allLeases = @(Get-DhcpServerv4Scope @from @scopeArgs | Get-DhcpServerv4Lease @from);
        $leases = @($allLeases | Where-Object { $_.AddressState -notlike "*Reservation" });
        Write-Progress -Activity "Lease Copy" -Status "Running steps 1/2..." -Id 1 -PercentComplete 50;
        $confirmArgs = @{}
        if ($PSBoundParameters.ContainsKey("Confirm"))
        {
            $confirmArgs.Confirm = $PSBoundParameters["Confirm"];
        }
        else
        {
            $confirmArgs.Confirm = $true;
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
            try
            {

                Add-DhcpServerv4Lease @to @leaseArgs @confirmArgs -ErrorAction Stop;
            }
            catch [Microsoft.Management.Infrastructure.CimException]
            {
                $ex = $_.Exception;
                if ($ex.NativeErrorCode -eq "AlreadyExists")
                {
                    Write-Warning $("Skipped {0} ({1}) as {2} is already taken." -f $leaseArgs.HostName, $leaseArgs.ClientId.ToUpper().Replace('-',':'), $leaseArgs.IPAddress);
                }
            }
            catch
            {
                throw $_.Exception.Message
            }
        }
        Write-ScriptProgress -Activity "Leases" -Id 2 -Completed;

        Write-Progress -Activity "Lease Copy" -Status "Running step 2/2..." -Id 1 -PercentComplete 75;
        if (-not $PSBoundParameters.ContainsKey("ExcludeReservations"))
        {
            Write-Verbose "Now creating any reservations...";
            $resrv = @(Get-DhcpServerv4Scope @from @scopeArgs | Get-DhcpServerv4Reservation @from)
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
                try
                {
                    Add-DhcpServerv4Reservation @to @resArgs @confirmArgs -ErrorAction Stop;
                }
                catch [Microsoft.Management.Infrastructure.CimException]
                {
                    $ex = $_.Exception;
                    if ($ex.NativeErrorCode -eq "AlreadyExists")
                    {
                        Write-Warning $("Skipped {0} ({1}) as {2} is already taken." -f $resArgs.Name, $resArgs.ClientId.ToUpper().Replace('-',':'), $resArgs.IPAddress);
                    }
                }
                catch
                {
                    throw $_.Exception.Message;
                }
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

    if ($SetName -like "*Credential")
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
        [ValidateSet("Scopes", "Options", "Reservations", "Leases", "Classes")]
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
                $Status = "Copying Lease {0}/{1}...";
            }
            "Classes"
            {
                $Status = "Copying Class {0}/{1}...";
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