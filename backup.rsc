# Script save settings and deleting old files
# https://forummikrotik.ru/viewtopic.php?t=7357
# tested on ROS 6.49.10 & 7.11.2
# updated 2023/10/23

:do {
    :local maxDaysAgo 30;
    :local autoDiskSelection true;
    :local diskName "flash";
    :local nameID [system identity get name];

    # Automatic disk selection function
    :local DiskFinder do={
        :local dskName "";
        :local allDisks [:toarray [/file find type="disk"]];
        :local extDisks "";
        :do {:set extDisks [:toarray [/disk find]]} on-error={}
        :local cntAllDisk [:len $allDisks];
        :local cntExtDisk [:len $extDisks];
        :if ($cntAllDisk!=0) do={:set dskName [/file get [($allDisks->0)] name]}
        :do {:if ($cntExtDisk!=0) do={:set dskName [/disk get [($extDisks->0)] name]}} on-error={}
        :return ($dskName);
    }


    # --------------------------------------------------------------------------------- # time translation function to UNIX-time
    :global DateTime2EpochDEL do={                                                      # https://forum.mikrotik.com/viewtopic.php?t=75555#p994849
        :local dTime [:tostr $1]; :local yesterDay false;                               # parses date formats:  "hh:mm:ss","mmm/dd hh:mm:ss","mmm/dd/yyyy hh:mm:ss",
        /system clock;                                                                  #                       "yyyy-mm-dd hh:mm:ss","mm-dd hh:mm:ss"
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

    # --------------------------------------------------------------------------------- # time conversion function from UNIX-time
    :global UnixToDateTimeDEL do={                                                      # https://forum.mikrotik.com/viewtopic.php?p=977170#p977170
        :local ZeroFill do={:return [:pick (100+$1) 1 3]}
        :local prMntDays [:toarray "0,0,31,59,90,120,151,181,212,243,273,304,334"];
        :local vGmt [:tonum [/system clock get gmt-offset]]; :if ($vGmt>0x7FFFFFFF) do={:set vGmt ($vGmt-0x100000000)}
        :if ($vGmt<0) do={:set vGmt ($vGmt*-1)}
        :local tzEpoch ($vGmt+[:tonum $1]);
        :if ($tzEpoch<0) do={:set tzEpoch 0};                                           # unsupported negative unix epoch
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

    # --------------------------------------------------------------------------------- # current time in nice format output function
    :local CurrentTime do={
        :global DateTime2EpochDEL;
        :global UnixToDateTimeDEL;
        :return [$UnixToDateTimeDEL [$DateTime2EpochDEL]];
    }

    # Main body of the script
    :put "$[system clock get time]\tStart saving settings and deleting old files on '$nameID' router";
    :if ($autoDiskSelection) do={
        :set $diskName [$DiskFinder];
        :put "$[system clock get time]\tAutomatic disk selection is ACTIVATED";
    } else={:put "$[system clock get time]\tDisk is specified by user is ACTIVATED"}
    :put "$[system clock get time]\tWork is done on disk: '$diskName'";
    :local filterName "";
    :if ([:len $diskName]!=0) do={
        :set filterName ($diskName."/".$nameID."_");
    } else={:set filterName ($nameID."_")}
    :local monthsOfYear ("jan","feb","mar","apr","may","jun","jul","aug","sep","oct","nov","dec");
    :local currentTime  [$CurrentTime];
    :local currentYear  [:pick $currentTime 0 4];
    :local currentMonth [:pick $currentTime 5 7];
    :set   currentMonth ($monthsOfYear->[($currentMonth-1)]);
    :local currentDay   [:pick $currentTime 8 10];
    :local idxCurrMonth ([:find $monthsOfYear $currentMonth -1]+1);
    :local hddFree 0;
    :local cntExtDsk 0;
    :do {:set cntExtDsk [:len [/disk find]]} on-error={}
    :do {
        :foreach fileIndex in=[/file find] do={
            :do {
                :local fileDate [/file get number=$fileIndex creation-time];
                :set fileDate [:pick $fileDate 0 11];
                :local fileMonth [:pick $fileDate 0 3 ];
                :set fileMonth ([:find $monthsOfYear $fileMonth -1 ]+1);
                :local fileDay  [:pick $fileDate 4 6 ];
                :local fileYear [:pick $fileDate 7 11];
                :local fileName [/file get number=$fileIndex name];
                :local sum 0;
                :set sum ($sum+(($currentYear-$fileYear)*365));
                :set sum ($sum+(($idxCurrMonth-$fileMonth)*30));
                :set sum ($sum+($currentDay-$fileDay));
                :if (($sum>=$maxDaysAgo) && ([file get number=$fileIndex name]~$filterName)) do={
                    /file remove [find name~$fileName];
                    :put "$[system clock get time]\tDeleting outdated file: '$fileName'";
                }
            } on-error={/log warning ("Error deleting outdated files")}
        }
        :set hddFree ([/system resource get free-hdd-space]/([/system resource get total-hdd-space]/100));
        :set maxDaysAgo ($maxDaysAgo-1);
    } while=($hddFree<5 && $cntExtDsk=0 && $maxDaysAgo>0);
    :if ($maxDaysAgo>0) do={
        :local fileNameCreate ($filterName.$currentYear.$currentMonth.$currentDay);
        :put "$[system clock get time]\tGenerating new file name: '$fileNameCreate'";
        :put "$[system clock get time]\tSaving a backup copy";
        /system backup save name=$fileNameCreate;
        :put "$[system clock get time]\tSaving system settings";
        /export file=$fileNameCreate;
        :put "$[system clock get time]\tSaving device log";
        /log print file=$fileNameCreate;
        /log warning "Backup completed successfully";
    } else={
        :put "$[system clock get time]\tNo disk space, free up disk space";
        /log warning ("No disk space, free up disk space for backup");
    }
    /system script environment remove [find name~"DEL"];                                # clearing memory
    :put "$[system clock get time]\tEnd of saving settings and delete old files";
} on-error={
    /log warning ("Error backup troubles");
    /system script environment remove [find name~"DEL"];                                # clearing memory
}
