Function Copy-DhcpExclusionRange() {
    [CmdletBinding(DefaultParameterSetName='ByCredential')]
    param (
        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'ByCredential')]
        [Alias("t", "to")]
        [string] $ToServer = $env:COMPUTERNAME,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'ByCredential')]
        [Alias("f", "from")]
        [string] $FromServer,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByCredential')]
        [Alias("toc")]
        [pscredential] $ToCredential,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByCredential')]
        [Alias("froc")]
        [pscredential] $FromCredential,

        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'ByCimSession')]
        [Alias("tcim")]
        [Microsoft.Management.Infrastructure.CimSession] $ToCimSession,

        [Parameter(Mandatory = $false, Position = 1, ParameterSetName = 'ByCimSession')]
        [Alias("fcim")]
        [Microsoft.Management.Infrastructure.CimSession] $FromCimSession
    )
    Begin {
        $private:bank = PrepareConnections -SetName $PSCmdlet.ParameterSetName -BoundParameters $PSBoundParameters
        $to = $private:bank.To
        $from = $private:bank.From

        if ($PSBoundParameters.ContainsKey("Verbose")) {
            $to.Verbose = $PSBoundParameters["Verbose"]
        }


    }
}