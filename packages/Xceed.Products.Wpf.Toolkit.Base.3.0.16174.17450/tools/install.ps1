param($installPath, $toolsPath, $package, $project)

Set-StrictMode -version 2.0

##-------------------------------------------------
## Globals
##-------------------------------------------------
[string] $basePath = "Registry::HKEY_CURRENT_USER\Software\Xceed Software"
[string] $licensesPath = $basePath + '\' + 'Licenses'

[byte[]] $NbDaysBits = 2, 7, 12, 17, 22, 26, 31, 37, 42, 47, 51, 55, 59, 62, 0xFF
[byte[]] $ProductCodeBits = 3, 16, 29, 41, 53, 61, 0xFF
[byte[]] $ProductVersionBits = 4, 15, 25, 34, 43, 50, 58, 0xFF
[byte[]] $ChecksumBits = 0, 9, 18, 27, 36, 45, 54, 63, 0xFF
[string] $AlphaNumLookup = "ABJCKTDL4UEMW71FNX52YGP98Z63HRS0"

[string[][]] $PackagesMap = 
        ('DGP','Xceed.Products.Wpf.DataGrid.Base'),`
        ('DGP','Xceed.Products.Wpf.DataGrid.Full'),`
        ('DGP','Xceed.Products.Wpf.DataGrid.Themes'),`
        ('WTK','Extended.Wpf.Toolkit.Plus'),`
        ('WTK','Xceed.Products.Wpf.Toolkit.AvalonDock'),`
        ('WTK','Xceed.Products.Wpf.Toolkit.AvalonDock.Themes'),`
        ('WTK','Xceed.Products.Wpf.Toolkit.Base'),`
        ('WTK','Xceed.Products.Wpf.Toolkit.Base.Themes'),`
        ('WTK','Xceed.Products.Wpf.Toolkit.ListBox'),`
        ('WTK','Xceed.Products.Wpf.Toolkit.ListBox.Themes'),`
        ('','')

[string[][]] $ProductIds = 
        ('',''),`
        ('ZIP',''),`
        ('SFX',''),`
        ('BKP',''),`
        ('WSL',''),`
        ('FTP',''),`
        ('SCO',''),`
        ('BEN',''),`
        ('CRY',''),`
        ('FTB',''),`
        ('ZIN',''),`
        ('ABZ',''),`
        ('GRD',''),`
        ('SCN',''),`
        ('ZIC',''),`
        ('SCC',''),`
        ('SUI',''),`
        ('SUN',''),`
        ('FTN',''),`
        ('FTC',''),`
        ('CHT',''),`
        ('DWN',''),`
        ('CHW',''),`
        ('IVN',''),`
        ('RDY',''),`
        ('EDN',''),`
        ('ZIL',''),`
        ('TAN',''),`
        ('DGF',''),`
        ('DGP','http://xceed.com/NuGet/Grid_WPF/default.aspx'),`
        ('WAN',''),`
        ('SYN',''),`
        ('ZIX',''),`
        ('ZII',''),`
        ('SFN',''),`
        ('ZRT',''),`
        ('ZRC',''),`
        ('UPS',''),`
        ('TDV',''),`
        ('ZRS',''),`
        ('XPT',''),`
        ('OFT',''),`
        ('GLT',''),`
        ('MET',''),`
        ('LET',''),`
        ('WST',''),`
        ('DGS',''),`
        ('LBS',''),`
        ('ZRP',''),`
        ('UPP',''),`
        ('LBW',''),`
        ('BLD',''),`
        ('SFT',''),`
        ('WTK','http://xceed.com/NuGet/Extended_WPF_Toolkit/default.aspx')

  
function shl{
param([System.UInt32] $value, [byte] $nb = 1)

    for([System.Int32] $i=0;$i -lt $nb;$i++)
    {
        $value = $value -band 0x7FFFFFFF
        $value *= 2
    }
    
    return $value
}


function shr{
param([System.UInt32] $value, [byte] $nb = 1)

    for([System.Int32] $i=0;$i -lt $nb;$i++)
    {
        $value = (($value-($value%2)) / 2)
    }
    
    return $value
}

##-------------------------------------------------
## Functions
##-------------------------------------------------
function MapBits{
param([System.Collections.BitArray] $barray, [System.UInt32] $val, [byte[]] $codeBits)

      for( [int] $i = 0; $i -lt ($codeBits.Length - 1); $i++ )
      {
        [int] $x = shl 1 $i
        $ba[ $codeBits[ $i ] ] = ( $val -band $x ) -ne 0
      }
}

function GetBytes{
param([System.Collections.BitArray] $ba)

    [byte[]] $array = New-Object System.Byte[] (9)
    for( [byte] $i = 0; $i -lt $ba.Length; $i++ )
    {
        if($ba[$i])
        {
            [int] $mod = ($i % 8)
            [int] $index = ( $i - $mod ) / 8
            $array[ $index ] = ($array[ $index ]) -bor ([byte]( shr 128 $mod ))
        }
    }
    return $array

}

function CalculateChecksum{
param([System.UInt16[]] $b )

    [System.UInt16] $dw1 = 0
    [System.UInt16] $dw2 = 0

    for([int] $i=0;$i -lt $b.Length;$i++)
    {
        $dw1 += $b[ $i ]
        $dw2 += $dw1
    }    

    ##Reduce to 8 bits
    [System.UInt16] $r1 = ($dw2 -bxor $dw1)
    [byte] $r2 = (shr $r1  8) -bxor ($r1 -band 0x00FF)

    return $r2
}

function GenAlpha {
param([System.Collections.BitArray] $ba)

  [string] $suffix = ''
  [int] $mask = 0x10
  [int] $value = 0
  for( [int] $i = 0; $i -lt $ba.Length;$i++)
  {
    if( $mask -eq 0 )
    {
      $suffix += $AlphaNumLookup[ $value ]
      $value = 0
      $mask = 0x10
    }

    if( $ba[ $i ] )
    {
      $value = $value -bor $mask
    }

    $mask = shr $mask
  }

  $suffix += $AlphaNumLookup[ $value ]

  return $suffix + 'A';
}

function FindId{
param([string] $id)

    [string] $prodId = ''
    for( [int] $i = 0; $i -lt $PackagesMap.Length;$i++)
    {
        if($PackagesMap[$i][1] -eq $id)
        {
            $prodId = $PackagesMap[$i][0]
            break
        }
    }
    
    if($prodId -ne '')
    {
      for( [int] $i = 0; $i -lt $ProductIds.Length;$i++)
      {
        if($ProductIds[$i][0] -eq $prodId)
        {
            return $i
        }
      }
    }
    
    return -1
}

function Create {
param([int] $pIndex, [int] $maj, [int] $min)

    ## Harcode others values that we dont need to customize.   
    $ba = New-Object System.Collections.BitArray 65
    $ba[6] = $true
    $ba[64] = $true

    [System.DateTime] $date = New-Object -t DateTime -a 2000,11,17
    [int] $days = [DateTime]::Today.Subtract($date).Days
    [int] $verNo = ($maj*10) + $min
    [string] $pPrefix = $ProductIds[$pIndex][0]
    [string] $prodId = "$pPrefix$verNo"
    
    MapBits $ba $pIndex $ProductCodeBits
    MapBits $ba $verNo $ProductVersionBits
    MapBits $ba $days $NbDaysBits
    
    [char[]] $a1 = $prodId.ToCharArray()
    [byte[]] $a2 = GetBytes $ba
    [System.UInt16[]] $a = New-Object System.UInt16[] ($a1.Length + $a2.Length)
    
    [System.Array]::Copy($a1,0,$a,0,$a1.Length)
    [System.Array]::Copy($a2,0,$a,$a1.Length,$a2.Length)
        
    [byte] $checksum = CalculateChecksum $a
    
    MapBits $ba $checksum $ChecksumBits

    return $prodId + (GenAlpha $ba)
}

function TestAndCreate{
param([string] $path)
    if(!(Test-Path $path))
    {
        $dump = New-Item $path
    }
}

function Setup{
param([int] $pIndex, [int] $major, [int] $minor)
    try
    {
        if($pIndex -lt 0)
        {
            return
        }        

        if(($major -lt 0) -or ($major -gt 9))
        {
            return
        }
            
        if(($minor -lt 0) -or ($minor -gt 9))
        {
            return    
        }

        ## Tester les erreurs
        [string] $prodPath = $licensesPath + '\' + $ProductIds[$pIndex][0]
        [string] $prodVer = "$major.$minor"

        TestAndCreate $basePath
        TestAndCreate $licensesPath
        TestAndCreate $prodPath

        [Microsoft.Win32.RegistryKey] $path = Get-Item $prodPath
        if($path.GetValue($prodVer, $null) -eq $null)
        {
            [string] $k = Create $pIndex $major $minor
            Set-ItemProperty -Path $prodPath -Name $prodVer -Value $k
        }
    }
    catch{}
}

##-------------------------------------------------
## Entry Point (Main)
##-------------------------------------------------

[int] $major = $package.Version.Version.Major
[int] $minor = $package.Version.Version.Minor
[int] $pIndex = FindId $package.Id

if($pIndex -gt 0)
{
    Setup $pIndex $major $minor
    
    [string] $pUrl = $ProductIds[$pIndex][1]
    if($pUrl.Length -gt 0)
    {
        [void] $project.DTE.ItemOperations.Navigate($pUrl)
    }
}
