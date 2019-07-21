using System;

namespace PrtgAPI.Tests.IntegrationTests
{
    public static partial class Settings
    {
        /// <summary>
        /// The settings in this file are not tracked.
        /// 
        /// To modify tracking:
        ///     git update-index --assume-unchanged PrtgAPI.Tests.IntegrationTests/Settings.Local.cs
        ///     git update-index --no-assume-unchanged PrtgAPI.Tests.IntegrationTests/Settings.Local.cs
        /// </summary>
        static Settings()
        {
            //Specify setting values below

            //PRTG Server
            Server = "ci-prtg-1";
            UserName = "prtgadmin";
            Password = "prtgadmin";

            ReadOnlyUserName = "prtguser";
            ReadOnlyPassword = "prtgadmin";

            //Local Server
            WindowsUserName = "Administrator";
            WindowsPassword = "prtgci1!";

            //Objects
            Probe = 1;
            Group = 2070;
            Device = 2055;
            Channel = 1;

            //Channel
            ChannelName = "Disk Time %";

            //Device
            DeviceName = "ci-prtg-1";
            DeviceTag = "C_OS_VMware";

            //Group
            GroupName = "Servers";
            GroupTag = "TestGroup";

            //Probe
            ProbeName = "Local Probe";
            ProbeTag = "TestProbe";

            //Sensor Types/States
            UpSensor = 2057;                 //HTTP
            WarningSensor = 2059;            //CPU Load
            DownSensor = 2060;               //Memory
            DownAcknowledgedSensor = 2071;   //Ping
            PausedSensor = 2061;             //Disk Free
            PausedByDependencySensor = 2062; //Pagefile Usage
            UnknownSensor = 2072;            //NetFlow V9
            ChannelSensor = 2065;            //Disk IO C:

            //Channel Limits
            ChannelErrorLimit = 2000;
            ChannelWarningLimit = 1000;
            ChannelErrorMessage = "Channel is in error";
            ChannelWarningMessage = "Channel is in warning";

            //Notification Actions
            NotificationAction = 301;
            NotificationActionName = "Email to all members of group PRTG Users Group";
            NotificationActionTag1 = "testActionOne";
            NotificationActionTag2 = "testActionTwo";

            //Schedules
            Schedule = 621;

            //Object Counts

            ProbesInTestServer = 1;

            GroupsInTestGroup = 1;
            GroupsInTestProbe = 3;
            GroupsInTestServer = 4;

            DevicesInTestGroup = 2;
            DevicesInTestProbe = 4;
            DevicesInTestServer = 4;

            SensorsInTestDevice = 16;
            SensorsInTestGroup = 23;
            SensorsInTestProbe = 30;
            SensorsInTestServer = 30;

            ChannelsInTestSensor = 21;

            NotificationTiggersOnDevice = 5;
            NotificationActionsInTestServer = 3;

            SchedulesInTestServer = 8;

            //Settings
            ParentTags = new[] { DeviceTag, GroupTag, ProbeTag };
            CustomInterval = new TimeSpan(0, 0, 10);
            CustomUnsupportedInterval = new TimeSpan(0, 0, 5);
            MaintenanceStart = new DateTime(2017, 2, 4, 17, 43, 0);
            MaintenanceEnd = new DateTime(2017, 2, 4, 17, 43, 0);
            Comment = "Integration Testing!";
            CommentSensor = 2056;
            FavoriteDevice = 2055;
            FavoriteSensor = 2056;
            Location = "Nuremberg, Germany";

            //Sensor Types
            WmiRemotePing = 2075;
            ExeXml = 2076;
            SNMP = 2077;
            SSLSecurityCheck = 2078;
            SensorFactory = 2079;
            WmiService = 2083;
            SqlServerDB = 2084;
        }
    }
}
