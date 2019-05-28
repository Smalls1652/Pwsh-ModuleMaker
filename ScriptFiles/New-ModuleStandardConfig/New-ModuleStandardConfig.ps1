[CmdletBinding()]
param(
    [string]$Author,
    [string]$CompanyName
)

$ModuleConfig = @{
    "Author" = $Author;
    "CompanyName" = $CompanyName
} | ConvertTo-Json

return $ModuleConfig