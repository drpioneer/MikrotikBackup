# Script save settings and deleting old files
# Script uses ideas by maksim.geynsberg, Jotne, rextended, Sertik, drPioneer
# https://forummikrotik.ru/viewtopic.php?p=91135#p91135
# tested on ROS 6.49.10 & 7.12
# updated 2024/02/06

:do {
  :local maxDaysAgo 180;    # maximum archive depth
  :local autoDiskSel true;  # automatic disk selection
  :local diskName "flash";  # setting disk name

  # --------------------------------------------------- # automatic disk selection function
  :local DiskFinder do={
    :local extDisks ""; :local dskName "";
    :local allDisks [:toarray [/file find type="disk"]];
    :do {:set extDisks [:toarray [/disk find]]} on-error={}
    :local cntAllDisk [:len $allDisks]; :local cntExtDisk [:len $extDisks];
    :if ($cntAllDisk!=0) do={:set dskName [/file get [($allDisks->0)] name]}
    :do {:if ($cntExtDisk!=0) do={:set dskName [/disk get [($extDisks->0)] name]}} on-error={}
    :return $dskName;
  }

  # --------------------------------------------------- # time translation function to UNIX-time
  :local DateTime2Epoch do={                            # https://forum.mikrotik.com/viewtopic.php?t=75555#p994849
    :local dTime [:tostr $1]; :local yesterDay false;   # parses date formats:  "hh:mm:ss","mm-dd hh:mm:ss",
    /system clock;                                      # "mmm/dd hh:mm:ss","mmm/dd/yyyy hh:mm:ss","yyyy-mm-dd hh:mm:ss"
    :local cYear [get date]; :if ($cYear~"....-..-..") do={:set cYear [:pick $cYear 0 4]} else={:set cYear [:pick $cYear 7 11]}
    :if ([:len $dTime]=10 or [:len $dTime]=11) do={:set dTime "$dTime 00:00:00"}
    :if ([:len $dTime]=15) do={:set dTime "$[:pick $dTime 0 6]/$cYear $[:pick $dTime 7 15]"}
    :if ([:len $dTime]=14) do={:set dTime "$cYear-$[:pick $dTime 0 5] $[:pick $dTime 6 14]"}
    :if ([:len $dTime]=8) do={:if ([:totime $1]>[get time]) do={:set yesterDay true}; :set dTime "$[get date] $dTime"}
    :if ([:tostr $1]="") do={:set dTime ("$[get date] $[get time]")}
    :local vDate [:pick $dTime 0 [:find $dTime " " -1]];
    :local vTime [:pick $dTime ([:find $dTime " " -1]+1) [:len $dTime]];
    :local vGmt [get gmt-offset]; :if ($vGmt>0x7FFFFFFF) do={:set vGmt ($vGmt-0x100000000)}
    :if ($vGmt<0) do={:set vGmt ($vGmt*-1)}
    :local arrMn [:toarray "0,0,31,59,90,120,151,181,212,243,273,304,334"];
    :local vdOff [:toarray "0,4,5,7,8,10"];
    :local month [:tonum [:pick $vDate ($vdOff->2) ($vdOff->3)]];
    :if ($vDate~".../../....") do={
      :set vdOff [:toarray "7,11,1,3,4,6"];
      :set month ([:find "xxanebarprayunulugepctovecANEBARPRAYUNULUGEPCTOVEC" [:pick $vDate ($vdOff->2) ($vdOff->3)] -1]/2);
      :if ($month>12) do={:set month ($month-12)}
    }
    :local year [:pick $vDate ($vdOff->0) ($vdOff->1)]; :if ((($year-1968)%4)=0) do={:set ($arrMn->1) -1; :set ($arrMn->2) 30}
    :local toTd ((($year-1970)*365)+(($year-1968)/4)+($arrMn->$month)+([:pick $vDate ($vdOff->4) ($vdOff->5)]-1));
    :if ($yesterDay) do={:set toTd ($toTd-1)};                                      # bypassing ROS6.xx time format problem after 00:00:00
    :return (((((($toTd*24)+[:pick $vTime 0 2])*60)+[:pick $vTime 3 5])*60)+[:pick $vTime 6 8]-$vGmt);
  }

  # --------------------------------------------------- # time conversion function from UNIX-time
  :local UnixToDateTime do={                            # https://forum.mikrotik.com/viewtopic.php?p=977170#p977170
    :local ZeroFill do={:return [:pick (100+$1) 1 3]}
    :local prMntDays [:toarray "0,0,31,59,90,120,151,181,212,243,273,304,334"];
    :local vGmt [:tonum [/system clock get gmt-offset]]; :if ($vGmt>0x7FFFFFFF) do={:set vGmt ($vGmt-0x100000000)}
    :if ($vGmt<0) do={:set vGmt ($vGmt*-1)}
    :local tzEpoch ($vGmt+[:tonum $1]);
    :if ($tzEpoch<0) do={:set tzEpoch 0};               # unsupported negative unix epoch
    :local yearStart (1970+($tzEpoch/31536000));
    :local tmpLeap (($yearStart-1968)/4); :if ((($yearStart-1968)%4)=0) do={:set ($prMntDays->1) -1; :set ($prMntDays->2) 30}
    :local tmpSec ($tzEpoch%31536000);
    :local tmpDays (($tmpSec/86400)-$tmpLeap);
    :if ($tmpSec<(86400*$tmpLeap) && (($yearStart-1968)%4)=0) do={
      :set tmpLeap ($tmpLeap-1); :set ($prMntDays->1) 0; :set ($prMntDays->2) 31; :set tmpDays ($tmpDays+1);
    }
    :if ($tmpSec<(86400*$tmpLeap)) do={:set yearStart ($yearStart-1); :set tmpDays ($tmpDays+365)}
    :local mnthStart 12 ; :while (($prMntDays->$mnthStart)>$tmpDays) do={:set mnthStart ($mnthStart-1)}
    :local dayStart [$ZeroFill (($tmpDays+1)-($prMntDays->$mnthStart))];
    :local timeStart (00:00:00+[:totime ($tmpSec%86400)]);
    :return "$yearStart/$[$ZeroFill $mnthStart]/$[$ZeroFill $dayStart] $timeStart";
  }

  # --------------------------------------------------- # main body of the script
  :local nameID [system identity get name]; :local filterName "";
  :local hddFree 0; :local cntExtDsk 0;
  :put "$[system clock get time]\tStart saving settings and deleting old files on '$nameID' router";
  :if ($autoDiskSel) do={
    :set $diskName [$DiskFinder];
    :put "$[system clock get time]\tAutomatic disk selection is ACTIVATED";
  } else={:put "$[system clock get time]\tDisk is specified by user is ACTIVATED"}
  :put "$[system clock get time]\tWork is done on disk '$diskName'";
  :if ([:len $diskName]!=0) do={:set filterName "$diskName/$nameID_"} else={:set filterName "$nameID_"}
  :do {:set cntExtDsk [:len [/disk find]]} on-error={}
  :do {
    :foreach fileIndex in=[/file find] do={
      :local secondsAgo ($maxDaysAgo*86400);
      :local fileName [/file get number=$fileIndex name];
      :local fileTime [$DateTime2Epoch [/file get number=$fileIndex creation-time]];
      :local timeDiff ([$DateTime2Epoch ""]-$fileTime);
      :if (($timeDiff>=$secondsAgo) && ([file get number=$fileIndex name]~$filterName)) do={
        /file remove [find name~$fileName];
        :put "$[system clock get time]\tDeleting outdated file '$fileName'";
      }
    }
    :set hddFree ([/system resource get free-hdd-space]/([/system resource get total-hdd-space]/100));
    :set maxDaysAgo ($maxDaysAgo-1);
  } while=($hddFree<5 && $cntExtDsk=0 && $maxDaysAgo>0);
  :if ($maxDaysAgo>0) do={
    :local monthsOfYear ("jan","feb","mar","apr","may","jun","jul","aug","sep","oct","nov","dec");
    :local currentTime [$UnixToDateTime [$DateTime2Epoch ""]];
    :local currentYear [:pick $currentTime 0 4];
    :local currentMonth ($monthsOfYear->[([:pick $currentTime 5 7] -1)]);
    :local currentDay [:pick $currentTime 8 10];
    :local fileNameCreate ($filterName.$currentYear.$currentMonth.$currentDay);
    :put "$[system clock get time]\tGenerating new file name '$fileNameCreate'";
    :put "$[system clock get time]\tSaving a backup copy";
    /system backup save name=$fileNameCreate;
    :put "$[system clock get time]\tSaving system settings";
    /export file=$fileNameCreate;
    :put "$[system clock get time]\tSaving device log";
    /log print file=$fileNameCreate;
  } else={
    :put "$[system clock get time]\tNo disk space, free up disk space";
    /log warning ("No disk space, free up disk space for backup");
  }
  :put "$[system clock get time]\tEnd of saving settings and delete old files";
} on-error={/log warning ("Error backup troubles")}
