﻿using System;
using System.Collections;
using System.ComponentModel;
using System.Configuration.Install;
using System.ServiceProcess;

namespace ConsulService
{
    [RunInstaller(true)]
    public partial class ProjectInstaller : System.Configuration.Install.Installer
    {
        public ProjectInstaller()
        {
            InitializeComponent();
        }

        protected override void OnAfterInstall(IDictionary savedState)
        {
            ServiceConfigurator.SetRecoveryOptions(this.serviceInstaller.ServiceName);
            using (ServiceController pc = new ServiceController(this.serviceInstaller.ServiceName))
            {
                pc.Start();
            }
        }
    }
}
