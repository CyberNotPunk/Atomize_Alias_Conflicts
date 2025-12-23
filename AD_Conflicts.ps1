Import-Module ActiveDirectory


$desktop = [Environment]::GetFolderPath("Desktop")
$outputFile = Join-Path -Path $desktop -ChildPath "rapport_conflits_alias_detaille.txt"


Write-Host "Recherche des utilisateurs dans l'AD..." -ForegroundColor Cyan
$users = Get-ADUser -Filter * -Properties mailNickname, proxyAddresses

if (-not $users) {
    Write-Host "Aucun utilisateur trouvé dans l'AD." -ForegroundColor Red
    exit
}


$aliasMap = @{}
$userConflicts = @{}

foreach ($user in $users) {
    $samAccountName = $user.SamAccountName

    
    if ($user.mailNickname) {
        $alias = $user.mailNickname
        if (-not $aliasMap.ContainsKey($alias)) {
            $aliasMap[$alias] = @()
        }
        if (-not $aliasMap[$alias].Contains($samAccountName)) {
            $aliasMap[$alias] += $samAccountName
        }
    }

    
    if ($user.proxyAddresses) {
        foreach ($proxy in $user.proxyAddresses) {
            if ($proxy -like "SMTP:*") {
                $alias = ($proxy -split ":")[1]
                if (-not $aliasMap.ContainsKey($alias)) {
                    $aliasMap[$alias] = @()
                }
                if (-not $aliasMap[$alias].Contains($samAccountName)) {
                    $aliasMap[$alias] += $samAccountName
                }
            }
        }
    }
}


$conflicts = $aliasMap.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 }


$userWithConflicts = @{}
foreach ($conflict in $conflicts) {
    $alias = $conflict.Key
    $usersInConflict = $conflict.Value
    foreach ($user in $usersInConflict) {
        if (-not $userWithConflicts.ContainsKey($user)) {
            $userWithConflicts[$user] = @{}
        }
        $otherUsers = $usersInConflict | Where-Object { $_ -ne $user }
        $userWithConflicts[$user][$alias] = $otherUsers
    }
}


if ($userWithConflicts.Count -gt 0) {
    "Rapport détaillé des conflits d'alias dans l'AD :`n" | Out-File -FilePath $outputFile -Encoding utf8
    $totalConflicts = 0
    foreach ($user in ($userWithConflicts.Keys | Sort-Object)) {
        $userConflictsList = $userWithConflicts[$user]
        $totalConflicts += $userConflictsList.Count
        "Utilisateur : $user" | Out-File -FilePath $outputFile -Append -Encoding utf8
        "Nombre de conflits : $($userConflictsList.Count)" | Out-File -FilePath $outputFile -Append -Encoding utf8
        foreach ($alias in $userConflictsList.Keys) {
            "  - Alias : $alias" | Out-File -FilePath $outputFile -Append -Encoding utf8
            "    En conflit avec : $($userConflictsList[$alias] -join ', ')" | Out-File -FilePath $outputFile -Append -Encoding utf8
        }
        "---" | Out-File -FilePath $outputFile -Append -Encoding utf8
    }
    "Nombre total d'utilisateurs avec conflits : $($userWithConflicts.Count)" | Out-File -FilePath $outputFile -Append -Encoding utf8
    "Nombre total de conflits d'alias : $totalConflicts" | Out-File -FilePath $outputFile -Append -Encoding utf8
    Write-Host "Le rapport détaillé des conflits d'alias a été exporté vers : $outputFile" -ForegroundColor Green
} else {
    "Aucun utilisateur avec conflit d'alias détecté dans l'AD." | Out-File -FilePath $outputFile -Encoding utf8
    Write-Host "Aucun utilisateur avec conflit d'alias détecté. Fichier créé : $outputFile" -ForegroundColor Green
}
