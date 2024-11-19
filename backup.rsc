# Script save settings and deleting old files
# Script uses ideas by maksim.geynsberg, Jotne, rextended, Sertik, drPioneer
# https://github.com/drpioneer/MikrotikBackup/blob/main/backup.rsc
# https://forummikrotik.ru/viewtopic.php?p=91135#p91135
# tested on ROS 6.49.17 & 7.16.1
# updated 2024/11/19

:do {
  :local maxDaysAgo 180;     # maximum archive depth
  :local autoDskSel true;    # automatic disk selection
  :local backupPath "flash"; # setting disk/folder name

  # automatic disk selection function
  :local DiskFinder do={
    :local extDisks ""; :local dskName ""; :local allDisks [:toarray [/file find type="disk"]]
    :do {:set extDisks [:toarray [/disk find]]} on-error={}
    :local cntAllDisk [:len $allDisks]; :local cntExtDisk [:len $extDisks]
    :if ($cntAllDisk!=0) do={:set dskName [/file get [($allDisks->0)] name]}
    :do {:if ($cntExtDisk!=0) do={:set dskName [/disk get [($extDisks->0)] name]}} on-error={}
    :return $dskName
  }

  # time translation function to UNIX time # https://forum.mikrotik.com/viewtopic.php?t=75555#p994849
  :local T2U do={ # $1-date/time in any format: "hh:mm:ss","mmm/dd hh:mm:ss","mmm/dd/yyyy hh:mm:ss","yyyy-mm-dd hh:mm:ss","mm-dd hh:mm:ss"
    :local dTime [:tostr $1]; :local yesterDay false; /system clock
    :local cYear [get date]; :if ($cYear~"....-..-..") do={:set $cYear [:pick $cYear 0 4]} else={:set $cYear [:pick $cYear 7 11]}
    :if ([:len $dTime]=10 or [:len $dTime]=11) do={:set $dTime "$dTime 00:00:00"}
    :if ([:len $dTime]=15) do={:set $dTime "$[:pick $dTime 0 6]/$cYear $[:pick $dTime 7 15]"}
    :if ([:len $dTime]=14) do={:set $dTime "$cYear-$[:pick $dTime 0 5] $[:pick $dTime 6 14]"}
    :if ([:len $dTime]=8) do={:if ([:totime $1]>[get time]) do={:set $yesterDay true}; :set $dTime "$[get date] $dTime"}
    :if ([:tostr $1]="") do={:set $dTime ("$[get date] $[get time]")}
    :local vDate [:pick $dTime 0 [:find $dTime " " -1]]; :local vTime [:pick $dTime ([:find $dTime " " -1]+1) [:len $dTime]]
    :local vGmt [get gmt-offset]; :if ($vGmt>0x7FFFFFFF) do={:set $vGmt ($vGmt-0x100000000)}; :if ($vGmt<0) do={:set $vGmt ($vGmt*-1)}
    :local arrMn [:toarray "0,0,31,59,90,120,151,181,212,243,273,304,334"]; :local vdOff [:toarray "0,4,5,7,8,10"]
    :local month [:tonum [:pick $vDate ($vdOff->2) ($vdOff->3)]]
    :if ($vDate~".../../....") do={
      :set $vdOff [:toarray "7,11,1,3,4,6"]
      :set $month ([:find "xxanebarprayunulugepctovecANEBARPRAYUNULUGEPCTOVEC" [:pick $vDate ($vdOff->2) ($vdOff->3)] -1]/2)
      :if ($month>12) do={:set $month ($month-12)}}
    :local year [:pick $vDate ($vdOff->0) ($vdOff->1)]
    :if ((($year-1968)%4)=0) do={:set ($arrMn->1) -1; :set ($arrMn->2) 30}
    :local toTd ((($year-1970)*365)+(($year-1968)>>2)+($arrMn->$month)+([:pick $vDate ($vdOff->4) ($vdOff->5)]-1))
    :if ($yesterDay) do={:set $toTd ($toTd-1)};   # bypassing ROS6.xx time format problem after 00:00:00
    :return (((((($toTd*24)+[:pick $vTime 0 2])*60)+[:pick $vTime 3 5])*60)+[:pick $vTime 6 8]-$vGmt)}

  # time conversion function from UNIX time # https://forum.mikrotik.com/viewtopic.php?p=977170#p977170
  :local U2T do={ # $1-UnixTime $2-OnlyTime
    :local ZeroFill do={:return [:pick (100+$1) 1 3]}
    :local prMntDays [:toarray "0,0,31,59,90,120,151,181,212,243,273,304,334"]
    :local vGmt [:tonum [/system clock get gmt-offset]]
    :if ($vGmt>0x7FFFFFFF) do={:set $vGmt ($vGmt-0x100000000)}
    :if ($vGmt<0) do={:set $vGmt ($vGmt*-1)}
    :local tzEpoch ($vGmt+[:tonum $1])
    :if ($tzEpoch<0) do={:set $tzEpoch 0}; # unsupported negative unix epoch
    :local yearStamp (1970+($tzEpoch/31536000))
    :local tmpLeap (($yearStamp-1968)>>2)
    :if ((($yearStamp-1968)%4)=0) do={:set ($prMntDays->1) -1; :set ($prMntDays->2) 30}
    :local tmpSec ($tzEpoch%31536000)
    :local tmpDays (($tmpSec/86400)-$tmpLeap)
    :if ($tmpSec<(86400*$tmpLeap) && (($yearStamp-1968)%4)=0) do={
      :set $tmpLeap ($tmpLeap-1); :set ($prMntDays->1) 0; :set ($prMntDays->2) 31; :set $tmpDays ($tmpDays+1)}
    :if ($tmpSec<(86400*$tmpLeap)) do={:set $yearStamp ($yearStamp-1); :set $tmpDays ($tmpDays+365)}
    :local mnthStamp 12; :while (($prMntDays->$mnthStamp)>$tmpDays) do={:set $mnthStamp ($mnthStamp-1)}
    :local dayStamp [$ZeroFill (($tmpDays+1)-($prMntDays->$mnthStamp))]
    :local timeStamp (00:00:00+[:totime ($tmpSec%86400)])
    :if ([:len $2]=0) do={:return "$yearStamp/$[$ZeroFill $mnthStamp]/$[$ZeroFill $dayStamp] $timeStamp"} else={:return "$timeStamp"}}

  # main body
  :local nameID [/system identity get name]; :local filterName ""; :local hddFree 0; :local cntExtDsk 0;
  :put "$[$U2T [$T2U]]\tStart saving settings and deleting old files on $nameID router"
  :if ($autoDskSel) do={
    :set $backupPath [$DiskFinder]
    :put "$[$U2T [$T2U]]\tAutomatic disk selection is ACTIVATED"
  } else={:put "$[$U2T [$T2U]]\tAutomatic disk selection is DISABLED"}
  :put "$[$U2T [$T2U]]\tWork is done along specified path '$backupPath'"
  :if ([:len $backupPath]!=0) do={:set filterName "$backupPath/$nameID_"} else={:set filterName "$nameID_"}
  :do {:set cntExtDsk [:len [/disk find]]} on-error={}
  :do {
    :local secondsAgo ($maxDaysAgo*86400)
    :foreach fileIndex in=[/file find] do={
      :local fileName [/file get number=$fileIndex name]; :local fileTime ""
      :do {
        :set $fileTime [$T2U [/file get number=$fileIndex creation-time]]
      } on-error={
        :set $fileTime [$T2U [/file get number=$fileIndex last-modified]]
      }
      :local timeDiff ([$T2U]-$fileTime)
      :if (($timeDiff>=$secondsAgo) && ([file get number=$fileIndex name]~$filterName)) do={
        /file remove [find name~$fileName]
        :put "$[$U2T [$T2U]]\tDeleting outdated file '$fileName'"}}
    :set hddFree ([/system resource get free-hdd-space]/([/system resource get total-hdd-space]/100))
    :set maxDaysAgo ($maxDaysAgo-1)
  } while=($hddFree<5 && $cntExtDsk=0 && $maxDaysAgo>0)
  :if ($maxDaysAgo>0) do={
    :local datStmp [$U2T [$T2U]]; :local curYear [:pick $datStmp 0 4]; :local curMont [:pick $datStmp 5 7];
    :local curDay [:pick $datStmp 8 10]; :local curHour [:pick $datStmp 11 13]; :local curMint [:pick $datStmp 14 16]
    :local fileName "$filterName$curYear-$curMont-$curDay_$curHour-$curMint"
    :put "$[$U2T [$T2U]]\tGenerating new file name '$fileName'"
    :put "$[$U2T [$T2U]]\tSaving a backup copy"
    /system backup save name=$fileName
    :put "$[$U2T [$T2U]]\tSaving system settings"
    /export file=$fileName
    :put "$[$U2T [$T2U]]\tSaving device log"
    /log print file=$fileName
    :do {
      :local dudeCfg ($fileName."dude.rsc"); :local dudeDb ($fileName."dude.db")
      /dude export file=$dudeCfg; /dude export-db backup-file=$dudeDb
    } on-error {:put "$[$U2T [$T2U]]\tThe Dude is not detected"}
  } else={
    :put "$[$U2T [$T2U]]\tNo disk space, free up disk space"
    /log warning "No disk space, free up disk space for backup"}
  :put "$[$U2T [$T2U]]\tEnd of saving settings and delete old files"} on-error={/log warning "Error backup troubles"}
