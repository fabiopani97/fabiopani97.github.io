#===============================================================================
# CARTOUCHE
#===============================================================================
# Nom du script   : Deverrouillage-ResetMDP.ps1
# Objectif        : Automatiser le deverrouillage d'un compte Active Directory
#                   et la reinitialisation de son mot de passe, tout en
#                   journalisant chaque action dans un fichier de log.
# Auteur          : Fabio Pani
# Date de creation: 27/07/2026
# Version         : 1.0
#
# Contexte        : Script demande par Luc Moreau (Administrateur S&R) pour
#                   reduire le temps de traitement des demandes de
#                   deverrouillage/reinitialisation de mot de passe.
#
# Prerequis       :
#   - Module PowerShell "ActiveDirectory" installe (inclus dans RSAT)
#   - Compte d'execution disposant des droits d'administration sur l'AD
#   - Dossier de destination du log existant (voir parametre $LogPath)
#===============================================================================


#===============================================================================
# BLOC DE PARAMETRES (variables centralisees)
#===============================================================================
# Toutes les valeurs modifiables du script sont regroupees ici, pour eviter
# d'avoir a chercher dans tout le code si l'on doit changer un reglage
# (ex : changer le chemin du log entre un environnement de test et de prod).

# Chemin du fichier de log ou seront tracees toutes les actions
$LogPath = "C:\Scripts\log-gestion-comptes.txt"


#===============================================================================
# FONCTION UTILITAIRE : ecriture dans le log
#===============================================================================
# Centralise le format des lignes de log pour garder une ecriture coherente
# partout dans le script (date - identifiant - action : resultat).
function Write-Log {
    param(
        [string]$Identifiant,
        [string]$Message
    )
    Add-Content -Path $LogPath -Value "$(Get-Date) - $Identifiant - $Message"
}


#===============================================================================
# ETAPE 1 : SAISIE ET VERIFICATION DU COMPTE
#===============================================================================
# On demande l'identifiant du compte a traiter, puis on verifie qu'il existe
# bien dans l'annuaire avant de tenter la moindre action dessus.

$Identifiant = Read-Host "Entrez l'identifiant du compte a traiter"

try {
    $Utilisateur = Get-ADUser -Identity $Identifiant -Properties LockedOut -ErrorAction Stop
}
catch {
    # Cas "compte introuvable" ou "droits insuffisants" : on log et on arrete
    Write-Host "Erreur : compte introuvable ou droits insuffisants."
    Write-Log -Identifiant $Identifiant -Message "ECHEC recherche du compte : $PSItem"
    return
}

Write-Host "Compte trouve : $($Utilisateur.SamAccountName)"


#===============================================================================
# ETAPE 2 : DEVERROUILLAGE DU COMPTE (si necessaire)
#===============================================================================
if ($Utilisateur.LockedOut) {
    try {
        Unlock-ADAccount -Identity $Identifiant -ErrorAction Stop
        Write-Host "Le compte a ete deverrouille."
        Write-Log -Identifiant $Identifiant -Message "Deverrouillage : SUCCES"
    }
    catch {
        Write-Host "Erreur lors du deverrouillage."
        Write-Log -Identifiant $Identifiant -Message "Deverrouillage : ECHEC - $PSItem"
    }
} else {
    Write-Host "Le compte n'etait pas verrouille."
    Write-Log -Identifiant $Identifiant -Message "Deverrouillage : NON NECESSAIRE"
}


#===============================================================================
# ETAPE 3 : REINITIALISATION DU MOT DE PASSE
#===============================================================================
# Le mot de passe est saisi en SecureString : il n'apparait jamais en clair
# a l'ecran ni dans le log (aucune information sensible n'est tracee).

$NouveauMDP = Read-Host "Entrez le nouveau mot de passe" -AsSecureString

try {
    Set-ADAccountPassword -Identity $Identifiant -Reset -NewPassword $NouveauMDP -ErrorAction Stop
    Write-Host "Le mot de passe a ete reinitialise."
    Write-Log -Identifiant $Identifiant -Message "Reinitialisation MDP : SUCCES"
}
catch {
    Write-Host "Erreur lors de la reinitialisation du mot de passe."
    Write-Log -Identifiant $Identifiant -Message "Reinitialisation MDP : ECHEC - $PSItem"
}

Write-Host "Traitement termine. Consultez le log : $LogPath"
