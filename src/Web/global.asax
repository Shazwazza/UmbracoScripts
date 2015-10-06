<%@ Application Inherits="Umbraco.Web.UmbracoApplication" Language="C#" %>
<%@ Import namespace="System.Diagnostics" %>
<%@ Import namespace="System.Reflection" %>
<%@ Import namespace="System.Web.Hosting" %>
<%@ Import namespace="Umbraco.Core" %>
<%@ Import namespace="Umbraco.Core.Logging" %>

<script language="C#" runat="server">

protected override void OnApplicationEnd(object sender, EventArgs e)
{
	base.OnApplicationEnd(sender, e);

	var runtime = (HttpRuntime)typeof(HttpRuntime).InvokeMember("_theRuntime",
                                BindingFlags.NonPublic
                                | BindingFlags.Static  
                                | BindingFlags.GetField,
                                null,
                                null,
                                null);
	if (runtime == null)
		return;

	var shutDownMessage = (string)runtime.GetType().InvokeMember("_shutDownMessage",
		BindingFlags.NonPublic
		| BindingFlags.Instance
		| BindingFlags.GetField,
		null,
		runtime,
		null);

	var shutDownStack = (string)runtime.GetType().InvokeMember("_shutDownStack",
		BindingFlags.NonPublic
		| BindingFlags.Instance
		| BindingFlags.GetField,
		null,
		runtime,
		null);

	var shutdownMsg = string.Format("{0}\r\n\r\n_shutDownMessage={1}\r\n\r\n_shutDownStack={2}",
		HostingEnvironment.ShutdownReason,
		shutDownMessage,
		shutDownStack);

	LogHelper.Info<UmbracoApplicationBase>("Application shutdown. Details: " + shutdownMsg);
}
    
</script>
