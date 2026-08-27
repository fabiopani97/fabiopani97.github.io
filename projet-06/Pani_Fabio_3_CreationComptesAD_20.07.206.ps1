#===============================================================================
# BLOC DE PARAMETRES (variables centralisees)
#===============================================================================
$CheminCSV = "C:\Scripts\usersP7.csv"
$Domaine   = "DC=ch-ocean,DC=co"
$LogPath   = "C:\Scripts\log-creation-comptes.txt"


#===============================================================================
# FONCTION UTILITAIRE : ecriture dans le log
#===============================================================================
function Write-Log {
    param(
        [string]$Identifiant,
        [string]$Message
    )
    try {
        Add-Content -Path $LogPath -Value "$(Get-Date) - $Identifiant - $Message" -ErrorAction Stop
    }
    catch {
        # Si meme l'ecriture du log echoue, on l'affiche au moins a l'ecran
        Write-Host "Impossible d'ecrire dans le log : $PSItem"
    }
}


#===============================================================================
# ETAPE 1 : IMPORT DU CSV
#===============================================================================
try {
    $ListeUtilisateurs = Import-Csv -Path $CheminCSV -ErrorAction Stop
}
catch {
    Write-Host "Erreur : impossible de lire le fichier CSV."
    Write-Log -Identifiant "N/A" -Message "ECHEC lecture du CSV : $PSItem"
    return
}


#===============================================================================
# ETAPE 2 : TRAITEMENT DE CHAQUE UTILISATEUR
#===============================================================================
foreach ($Ligne in $ListeUtilisateurs) {

    # --- Verification de l'existence du compte ---
    $ExisteDeja = $false
    try {
        Get-ADUser -Identity $Ligne.SamAccountName -ErrorAction Stop
        $ExisteDeja = $true
    }
    catch {
        $ExisteDeja = $false
    }

    if ($ExisteDeja) {
        Write-Host "$($Ligne.SamAccountName) existe deja, on passe."
        Write-Log -Identifiant $Ligne.SamAccountName -Message "Creation : IGNOREE (deja existant)"
        continue
    }

    # --- Creation du compte ---
   try {
        # On recupere le VRAI chemin de l'OU directement depuis l'annuaire
        $OUCible = Get-ADOrganizationalUnit -Filter "Name -eq '$($Ligne.OU)'" -ErrorAction Stop

        $MotDePasse = ConvertTo-SecureString $Ligne.Password -AsPlainText -Force

        New-ADUser -SamAccountName $Ligne.SamAccountName `
                   -Name "$($Ligne.GivenName) $($Ligne.Surname)" `
                   -GivenName $Ligne.GivenName `
                   -Surname $Ligne.Surname `
                   -Path $OUCible.DistinguishedName `
                   -AccountPassword $MotDePasse `
                   -Enabled $true `
                   -ErrorAction Stop

        Write-Host "$($Ligne.SamAccountName) a ete cree."
        Write-Log -Identifiant $Ligne.SamAccountName -Message "Creation : SUCCES"
    }
    catch {
        Write-Host "Erreur lors de la creation de $($Ligne.SamAccountName)."
        Write-Log -Identifiant $Ligne.SamAccountName -Message "Creation : ECHEC - $PSItem"
        continue
    }

    # --- Ajout au groupe ---
    try {
        Add-ADGroupMember -Identity $Ligne.Group -Members $Ligne.SamAccountName -ErrorAction Stop
        Write-Host "$($Ligne.SamAccountName) ajoute au groupe $($Ligne.Group)."
        Write-Log -Identifiant $Ligne.SamAccountName -Message "Ajout groupe $($Ligne.Group) : SUCCES"
    }
    catch {
        Write-Host "Erreur lors de l'ajout au groupe pour $($Ligne.SamAccountName)."
        Write-Log -Identifiant $Ligne.SamAccountName -Message "Ajout groupe $($Ligne.Group) : ECHEC - $PSItem"
    }
}