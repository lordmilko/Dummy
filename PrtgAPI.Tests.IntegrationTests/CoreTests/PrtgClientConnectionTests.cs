﻿using System;
using System.Net;
using System.Net.Http;
using System.Reflection;
using System.ServiceProcess;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using PrtgAPI.Helpers;

namespace PrtgAPI.Tests.IntegrationTests
{
    [TestClass]
    public class PrtgClientConnectionTests : BasePrtgClientTest
    {
        [TestMethod]
        [ExpectedException(typeof(ArgumentNullException))]
        public void Logic_Client_NullCredentials()
        {
            var server = $"http://{Settings.Server}";
            string username = null;
            string password = null;

            var client = new PrtgClient(server, username, password);
        }

        [TestMethod]
        public void Logic_Client_InvalidCredentials()
        {
            var server = $"http://{Settings.Server}";
            string username = "a";
            string password = "a";

            try
            {
                var client = new PrtgClient(server, username, password);
                Assert2.Fail("Invalid credentials were specified however an exception was not thrown");
            }
            catch (HttpRequestException ex)
            {
                if (ex.Message != "Could not authenticate to PRTG; the specified username and password were invalid.")
                {
                    Assert2.Fail(ex.Message);
                }
            }
            catch (Exception ex)
            {
                Assert2.Fail(ex.Message);
            }
        }

        [TestMethod]
        [ExpectedException(typeof(ArgumentNullException))]
        public void Logic_Client_NullServer()
        {
            string server = null;

            var client = new PrtgClient(server, Settings.Username, Settings.Password);
        }

        [TestMethod]
        public void Logic_Client_InvalidServer()
        {
            string server = "a";

            try
            {
                var client = new PrtgClient(server, Settings.Username, Settings.Password);
            }
            catch (WebException ex)
            {
                if (ex.Message != $"The remote name could not be resolved: '{server}'")
                    Assert2.Fail($"Request did not fail with expected error message: {ex.Message}");
            }
        }

        [TestMethod]
        [ExpectedException(typeof(PrtgRequestException))]
        public void Logic_Client_InvalidRequest()
        {
            var client = new PrtgClient(Settings.ServerWithProto, Settings.Username, Settings.Password);
            client.DeleteObject(0);
        }

        [TestMethod]
        [ExpectedException(typeof(PrtgRequestException))]
        public async Task Logic_Client_InvalidRequestAsync()
        {
            var client = new PrtgClient(Settings.ServerWithProto, Settings.Username, Settings.Password);
            await client.DeleteObjectAsync(0);
        }

        [TestMethod]
        public void Logic_Client_ConnectWithHttp()
        {
            var server = $"http://{Settings.Server}";

            var client = new PrtgClient(server, Settings.Username, Settings.Password);
        }

        [TestMethod]
        public void Logic_Client_ConnectWithHttps()
        {
            var server = $"https://{Settings.Server}";

            try
            {
                var client = new PrtgClient(server, Settings.Username, Settings.Password);
            }
            catch (WebException ex)
            {
                if (ex.InnerException != null)
                {
                    if (ex.InnerException.Message.StartsWith("No connection could be made because the target machine actively refused it"))
                    {
                        if(Settings.Protocol != HttpProtocol.HTTP)
                            Assert2.Fail($"{ex.Message}. This may indicate your PRTG Server does not accept HTTPS or that your certificate is invalid. If your server does not accept HTTPS please change your Protocol in Settings.cs");
                    }
                    else
                        throw;
                }
                else
                    throw;
            }
        }

        [TestMethod]
        public void Logic_Client_RetryRequest()
        {
            Logic_Client_RetryRequestInternal(client => client.GetSensors(), false);
        }

        [TestMethod]
        public void Logic_Client_RetryRequest_Async()
        {
            Logic_Client_RetryRequestInternal(client =>
            {
                var sensors = client.GetSensorsAsync().Result;
            }, true);
        }

        private void Logic_Client_RetryRequestInternal(Action<PrtgClient> action, bool isAsync)
        {
            var initialThread = Thread.CurrentThread.ManagedThreadId;

            Impersonator.ExecuteAction(() =>
            {
                var retriesMade = 0;
                var retriesToMake = 3;

                var coreService = new ServiceController("PRTGCoreService", Settings.Server);

                var client = new PrtgClient(Settings.ServerWithProto, Settings.Username, Settings.Password);
                client.RetryRequest += (sender, args) =>
                {
                    Logger.LogTestDetail($"Handling retry {retriesMade + 1}");

                    if(!isAsync)
                        Assert2.AreEqual(initialThread, Thread.CurrentThread.ManagedThreadId, "Event was not handled on initial thread");
                    retriesMade++;
                };
                client.RetryCount = retriesToMake;

                Logger.LogTestDetail("Stopping PRTG Service");

                coreService.Stop();
                coreService.WaitForStatus(ServiceControllerStatus.Stopped);

                try
                {
                    action(client);
                }
                catch (AggregateException ex)
                {
                    if (ex.InnerException != null && ex.InnerException.GetType() == typeof (AssertFailedException))
                        throw ex.InnerException;
                }
                catch (WebException)
                {
                }
                finally
                {
                    Logger.LogTestDetail("Starting PRTG Service");
                    coreService.Start();
                    coreService.WaitForStatus(ServiceControllerStatus.Running);

                    Logger.LogTestDetail("Sleeping for 20 seconds");
                    Thread.Sleep(20000);

                    Logger.LogTestDetail("Refreshing and sleeping for 20 seconds");
                    client.RefreshObject(Settings.Device);
                    Thread.Sleep(20000);
                }

                Assert2.AreEqual(retriesToMake, retriesMade, "An incorrect number of retries were made.");
            });
        }
    }
}