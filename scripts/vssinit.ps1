Param(
  [Parameter(Mandatory=$true)]
  [String] $StorageAccountName,

  [Parameter(Mandatory=$true)]
  [String] $StorageAccountKey,

  [Parameter(Mandatory=$true)]
  [String] $DriveLetter,

  [Parameter(Mandatory=$true)]
  [String] $FileShareLocation,

  [Parameter(Mandatory=$true)]
  [String] $SharedConfigPath,

  [Parameter(Mandatory=$true)]
  [String] $ConfigKeyPassword,

  [Parameter(Mandatory=$true)]
  [String] $CertStorePath,

  [Parameter(Mandatory=$true)]
  [String] $CertStoreKeyPassword
)

# Add file share user
net user $StorageAccountName $StorageAccountKey /ADD /Y

# Mount Azure File Share as drive
net use "$($DriveLetter):" $FileShareLocation  /u:$StorageAccountName $StorageAccountKey /PERSISTENT:YES

# Enable IIS Shared Configuration
$PhysicalPath = [System.IO.Path]::Combine($FileShareLocation, $SharedConfigPath)
$kp = ConvertTo-SecureString -AsPlainText -Force $ConfigKeyPassword
$pass = ConvertTo-SecureString -AsPlainText -Force $StorageAccountKey
Enable-IISSharedConfig -Username $StorageAccountName -Password $pass -KeyEncryptionPassword $kp -PhysicalPath $PhysicalPath -Force

# Enable IIS Central Certificate Store
$CertsPass = ConvertTo-SecureString -AsPlainText -Force $CertStoreKeyPassword
$CertStoreLocation = [System.IO.Path]::Combine($FileShareLocation, $CertStorePath)
Enable-IISCentralCertProvider -UserName $StorageAccountName -Password $pass -CertStoreLocation $CertStoreLocation -PrivateKeyPassword $CertsPass