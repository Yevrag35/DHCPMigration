Function Copy-DhcpExclusionRange() {
    [CmdletBinding(DefaultParameterSetName='ByCredential', SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [IPAddress[]] $ScopeId,

        [Parameter(Mandatory = $false, Position = 1, ParameterSetName = 'ByCredential')]
        [Alias("t", "to")]
        [string] $ToServer = $env:COMPUTERNAME,

        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'ByCredential')]
        [Alias("f", "from")]
        [string] $FromServer,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByCredential')]
        [Alias("toc")]
        [pscredential] $ToCredential,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByCredential')]
        [Alias("froc")]
        [pscredential] $FromCredential,

        [Parameter(Mandatory = $false, Position = 1, ParameterSetName = 'ByCimSession')]
        [Alias("tcim")]
        [Microsoft.Management.Infrastructure.CimSession] $ToCimSession,

        [Parameter(Mandatory = $false, Position = 2, ParameterSetName = 'ByCimSession')]
        [Alias("fcim")]
        [Microsoft.Management.Infrastructure.CimSession] $FromCimSession,

        [Parameter(Mandatory=$false)]
        [switch] $Force
    )
    Begin {
        $private:bank = PrepareConnections -SetName $PSCmdlet.ParameterSetName -BoundParameters $PSBoundParameters
        $to = $private:bank.To
        $to.Confirm = $false
        $from = $private:bank.From

        if ($PSBoundParameters.ContainsKey("Verbose")) {
            $to.Verbose = $PSBoundParameters["Verbose"]
        }

        if (-not $PSBoundParameters.ContainsKey("ScopeId")) {

            $moveTheseScopes = Get-DhcpServerv4Scope @from
        }
        else {

            $moveTheseScopes = Get-DhcpServerv4Scope -ScopeId $ScopeId @from
        }
    }
    Process {

        $copyExclusions = $moveTheseScopes | Get-DhcpServerv4ExclusionRange @from

        foreach ($exclusion in $copyExclusions) {

            $exclusionInfo = @{
                ScopeId = $exclusion.ScopeId
                StartRange = $exclusion.StartRange
                EndRange = $exclusion.EndRange
            }

            $msg = "ScopeId: {0} ({1}-{2})" -f $exclusion.ScopeId, $exclusion.StartRange, $exclusion.EndRange
            if ($PSCmdlet.ShouldProcess($msg, "Adding Exclusion Range")) {

                Add-DhcpServerv4ExclusionRange @exclusionInfo @to
            }
        }
    }
}