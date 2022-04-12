# Script save settings and deleting old files
# https://forummikrotik.ru/viewtopic.php?t=7357
# tested on ROS 6.49.5
# updated 2022/04/09

:do {
    :local maxDaysAgo 30;
    :local autoDiskSelection true;
    :local diskName "flash";

    # Automatic disk selection function
    :local DiskFinder do={
        :local dskName "";
        :local allDisks [:toarray [/file find type="disk"]];
        :local extDisks [:toarray [/disk find]];
        :local cntAllDisk [:len $allDisks];
        :local cntExtDisk [:len $extDisks];
        :if ($cntAllDisk!=0) do={:set dskName [/file get [($allDisks->0)] name]}
        :if ($cntExtDisk!=0) do={:set dskName [/disk get [($extDisks->0)] name]}
        :return ($dskName);
    }

    # Main body of the script
    :local nameID [system identity get name];
    :put "$[system clock get time] - Start saving settings and deleting old files on '$nameID' router.";
    :if ($autoDiskSelection) do={
        :set $diskName [$DiskFinder];
        :put "$[system clock get time] - Automatic disk selection is ACTIVATED.";
    } else={
        :put "$[system clock get time] - Disk is specified by user is ACTIVATED.";
    }
    :put "$[system clock get time] - Work is done on disk: '$diskName'.";
    :local filterName "";
    :if ([:len $diskName]!=0) do={
        :set filterName ($diskName."/".$nameID."_");
    } else={
        :set filterName ($nameID."_");
    }
    :local monthsOfYear ("jan","feb","mar","apr","may","jun","jul","aug","sep","oct","nov","dec");
    :local currentDate  [system clock get date];
    :local currentDay   [:pick $currentDate 4 6 ];
    :local currentMonth [:pick $currentDate 0 3 ];
    :local currentYear  [:pick $currentDate 7 11];
    :local idxCurrMonth ([:find $monthsOfYear $currentMonth -1 ] +1);
    :local hddFree 0;
    :do {
        :foreach fileIndex in=[file find] do={
            :do {
                :local fileDate   [file get number=$fileIndex creation-time];
                :set   fileDate   [:pick $fileDate 0 11];
                :local fileMonth  [:pick $fileDate 0 3 ];
                :set   fileMonth ([:find $monthsOfYear $fileMonth -1 ] +1);
                :local fileDay    [:pick $fileDate 4 6 ];
                :local fileYear   [:pick $fileDate 7 11];
                :local fileName   [file get number=$fileIndex name];
                :local sum 0;
                :set sum ($sum + (($currentYear  - $fileYear)  * 365));
                :set sum ($sum + (($idxCurrMonth - $fileMonth) * 30 ));
                :set sum ($sum + ($currentDay - $fileDay));
                :if ($sum >= $maxDaysAgo && [file get number=$fileIndex name]~$filterName) do={
                    /file remove [find name~$fileName];
                    :put "$[system clock get time] - Deleting outdated file: '$fileName'.";
                }
            } on-error={ /log warning ("Script error. Error deleting outdated files.") }
        }
        :set hddFree ([/system resource get free-hdd-space]/([/system resource get total-hdd-space]/100));
        :set maxDaysAgo ($maxDaysAgo-1);
    } while=(($hddFree < 5) && [:len [/disk find]] = 0) ;

    :local fileNameCreate ($filterName.$currentYear.$currentMonth.$currentDay);
    :put "$[system clock get time] - Generating new file name: '$fileNameCreate'";
    :put "$[system clock get time] - Saving a backup copy.";
    /system backup save name=$fileNameCreate;
    :put "$[system clock get time] - Saving system settings.";
    /export file=$fileNameCreate;
    :put "$[system clock get time] - Saving device log.";
    /log print file=$fileNameCreate;
    /log info "Backup completed successfully.";
    :put "$[system clock get time] - End of saving settings and delete old files on '$nameID' router .";
} on-error={ /log warning ("Script error. Backup troubles.") }
