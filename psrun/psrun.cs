// from http://www.leporelo.eu/blog.aspx?id=run-scheduled-tasks-with-winform-gui-in-powershell
// A gui program that runs powershell commands without showing a console window
// Example: 
// PSRun.exe "Add-Type –a system.windows.forms; $form = new-object Windows.Forms.Form; [void]$form.showdialog()" 
// v.s. 
// powershell "Add-Type –a system.windows.forms; $form = new-object Windows.Forms.Form; [void]$form.showdialog()"
using System;
using System.Management.Automation.Runspaces;
using System.Windows.Forms;

namespace PowershellRunner
{
	static class Program
	{
		[STAThread]
		static void Main(string[] args)
		{
			try
			{
				if (args == null || args.Length != 1)
					throw new ApplicationException("Empty argument list");
				Runspace runspace = RunspaceFactory.CreateRunspace();
				runspace.Open();
				Pipeline pipeline = runspace.CreatePipeline();
				pipeline.Commands.AddScript(args[0]);
				pipeline.Invoke();
			}
			catch(Exception e)
			{
				MessageBox.Show(e.Message);
			}
		}
	}
}
