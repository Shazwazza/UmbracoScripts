using System;
using System.Text;
using System.Threading;
using System.Collections;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Web.Mvc;
using Umbraco.Core;
using Umbraco.Core.Services;
using Umbraco.Core.Macros;
using Umbraco.Core.Models;
using Umbraco.Web.WebApi;
using Umbraco.Web.Mvc;
using Umbraco.Web.Models;
using System.Globalization;
using System.Linq;
using System.Net.Http.Formatting;
using System.Web;
using System.Web.Hosting;
using System.Web.Mvc;
using System.Web.Mvc;
using System.Web.Routing;
using Umbraco.Core;
using Umbraco.Web.Models.Trees;
using Umbraco.Web.Trees;
using Umbraco.Web.Mvc;
using System.Diagnostics;

// need: this file, Zbu.WebManagement, Interop.mscoree.dll
// hit /LoadTest on a fresh install

// restarts: either set a % on the create calls, or call restart

namespace Zbu.LoadTest
{
    public class LoadTestController : Controller
    {
        private static readonly Random _random = new Random();
        private static readonly object _locko = new object();
        
        private static volatile int _containerId = -1;
        
        private const string _containerAlias = "LoadTestContainer";
        private const string _contentAlias = "LoadTestContent";
        private const int _textboxDefinitionId = -88;
        private const int _maxCreate = 1000;
        
        private static readonly string HeadHtml = @"<html>
<head>
  <title>LoadTest</title>
  <style>
    body { font-family: arial; }
    a,a:visited { color: blue; }
    h1 { margin: 0; padding: 0; font-size: 120%; font-weight: bold; }
    h1 a { text-decoration: none; }
    div.block { margin: 20px 0; }
    ul { margin:0; }
    div.ver { font-size: 80%; }
    div.head { padding:0 0 10px 0; margin: 0 0 20px 0; border-bottom: 1px solid #cccccc; }
  </style>
</head>
<body>
  <div class=""head"">
  <h1><a href=""/LoadTest"">LoadTest</a></h1>
  <div class=""ver"">" + System.Configuration.ConfigurationManager.AppSettings["umbracoConfigurationStatus"] + @"</div>
  </div>
";
        
        private const string FootHtml = @"</body>
</html>";
        
        private static readonly string _containerTemplateText = @"
@inherits Umbraco.Web.Mvc.UmbracoTemplatePage
@{
    Layout = null;
    var container = Umbraco.TypedContentAtRoot().OfTypes(""" + _containerAlias + @""").FirstOrDefault();
    var contents = container.Children().ToArray();
    var groups = contents.GroupBy(x => x.GetPropertyValue<string>(""origin""));
    var id = contents.Length > 0 ? contents[0].Id : -1;
    var wurl = Request.QueryString[""u""] == ""1"";
    var missing = contents.Length > 0 && contents[contents.Length - 1].Id - contents[0].Id >= contents.Length;
}
" + HeadHtml + @"
<div class=""block"">
<span @Html.Raw(missing ? ""style=\""color:red;\"""" : """")>@contents.Length items</span>
<ul>
@foreach (var group in groups)
{
    <li>@group.Key: @group.Count()</li>
}
</ul></div>
<div class=""block"">
@foreach (var content in contents)
{
	while (content.Id > id)
	{
		<div style=""color:red;"">@id :: MISSING</div>
		id++;
	}
    if (wurl)
    {
        <div>@content.Id :: @content.Name :: @content.Url</div>
    }
    else
    {
        <div>@content.Id :: @content.Name</div>
    }	id++;
}
</div>
" + FootHtml;
                
        private ActionResult ContentHtml(string s)
        {
            return Content(HeadHtml + s + FootHtml);
        }
        
        public ActionResult Index()
        {
            var res = EnsureInitialize();
            if (res != null) return res;
            
            var html = @"Welcome. You can:
<ul>
    <li><a href=""/LoadTestContainer"">List existing contents</a> (u:url)</li>
    <li><a href=""/LoadTest/Create?o=browser"">Create a content</a> (o:origin, r:restart, n:number)</li>
    <li><a href=""/LoadTest/Clear"">Clear all contents</a></li>
    <li><a href=""/LoadTest/Domains"">List the current domains in w3wp.exe</a></li>
    <li><a href=""/LoadTest/Restart"">Restart the current AppDomain</a></li>
    <li><a href=""/LoadTest/Recycle"">Recycle the AppPool</a></li>
    <li><a href=""/LoadTest/Die"">Cause w3wp.exe to die</a></li>
</ul>
";
           
            return ContentHtml(html);
        }
        
        private ActionResult EnsureInitialize()
        {
            if (_containerId > 0) return null;
            
            lock (_locko)
            {
                if (_containerId > 0) return null;
                
                var contentTypeService = ApplicationContext.Current.Services.ContentTypeService;
                var contentType = contentTypeService.GetContentType(_contentAlias);
                if (contentType == null)
                    return ContentHtml("Not installed, first you must <a href=\"/LoadTest/Install\">install</a>.");
                
                var containerType = contentTypeService.GetContentType(_containerAlias);
                if (containerType == null)
                    return ContentHtml("Panic! Container type is missing.");

                var contentService = ApplicationContext.Current.Services.ContentService;
                var container = contentService.GetContentOfContentType(containerType.Id).FirstOrDefault();
                if (container == null)
                    return ContentHtml("Panic! Container is missing.");
                
                _containerId = container.Id;
                return null;
            }
        }
        
        public ActionResult Install()
        {
            var dataTypeService = ApplicationContext.Current.Services.DataTypeService;
            
            var dataType = dataTypeService.GetDataTypeDefinitionById(Constants.System.DefaultContentListViewDataTypeId);
            var preVals = dataTypeService.GetPreValuesCollectionByDataTypeId(dataType.Id);
            var dict = preVals.FormatAsDictionary();
            
            if (!dict.ContainsKey("pageSize")) dict["pageSize"] = new PreValue("10");
            dict["pageSize"].Value = "200";
            dataTypeService.SavePreValues(dataType, dict);

            var contentTypeService = ApplicationContext.Current.Services.ContentTypeService;
            
            var contentType = new ContentType(-1)
            {
                Alias = _contentAlias,
                Name = "LoadTest Content",
                Description = "Content for LoadTest",
                Icon = "icon-document"
            };
            var def = ApplicationContext.Current.Services.DataTypeService.GetDataTypeDefinitionById(_textboxDefinitionId);
            contentType.AddPropertyType(new PropertyType(def)
            {
                Name = "Origin",
                Alias = "origin",
                Description = "The origin of the content.",
            });
            contentTypeService.Save(contentType);

            var containerTemplate = ImportTemplate(ApplicationContext.Current.Services,
                "~/Views/LoadTestContainer.cshtml", "LoadTestContainer", "LoadTestContainer", _containerTemplateText);
            
            var containerType = new ContentType(-1)
            {
                Alias = _containerAlias,
                Name = "LoadTest Container",
                Description = "Container for LoadTest content",
                Icon = "icon-document",
                AllowedAsRoot = true,
                IsContainer = true
            };
            containerType.AllowedContentTypes = containerType.AllowedContentTypes.Union(new[]
            {
                new ContentTypeSort(new Lazy<int>(() => contentType.Id), 0, contentType.Alias),
            });
            containerType.AllowedTemplates = containerType.AllowedTemplates.Union(new[] { containerTemplate });
            containerType.SetDefaultTemplate(containerTemplate);
            contentTypeService.Save(containerType);
                        
            var contentService = ApplicationContext.Current.Services.ContentService;
            var content = contentService.CreateContent("LoadTestContainer", -1, _containerAlias);
            contentService.SaveAndPublishWithStatus(content);
            
            return ContentHtml("Installed.");
        }
        
        public ActionResult Create(int n = 1, int r = 0, string o = null)
        {
            var res = EnsureInitialize();
            if (res != null) return res;

            if (r < 0) r = 0;
            if (r > 100) r = 100;
            var restart = GetRandom(0, 100) > (100 - r);

            var contentService = ApplicationContext.Current.Services.ContentService;
            
            if (n < 1) n = 1;
            if (n > _maxCreate) n = _maxCreate;
            for (int i = 0; i < n; i++)
            {
                var name = Guid.NewGuid().ToString("N").ToUpper() + "-" + (restart ? "R" : "X") + "-" + o;
                var content = contentService.CreateContent(name, _containerId, _contentAlias);
                content.SetValue("origin", o);
                contentService.SaveAndPublishWithStatus(content);
            }
                        
            if (restart)
                DoRestart();

            return ContentHtml("Created "  + n + " content"
                +  (restart ? ", and restarted" : "") 
                + ".");
        }
        
        private int GetRandom(int minValue, int maxValue)
        {
            lock (_locko)
            {
                return _random.Next(minValue, maxValue);
            }
        }
        
		public ActionResult Clear()
		{
            var res = EnsureInitialize();
            if (res != null) return res;

			var contentType = ApplicationContext.Current.Services.ContentTypeService.GetContentType(_contentAlias);
			ApplicationContext.Current.Services.ContentService.DeleteContentOfType(contentType.Id);
            
            return ContentHtml("Cleared.");
		}
        
        private void DoRestart()
        {
            HttpContext.User = null;
            System.Web.HttpContext.Current.User = null;
            Thread.CurrentPrincipal = null;            
			HttpRuntime.UnloadAppDomain();
        }
		
		public ActionResult Restart()
		{
            DoRestart();
            
			return ContentHtml("Restarted.");
		}
        
        public ActionResult Die()
        {
            var timer = new System.Threading.Timer(_ => 
            {
                throw new Exception("die!");
            });
            timer.Change(100,0);
           
            return ContentHtml("Dying.");
        }

        public ActionResult Domains()
        {
            var currentDomain = AppDomain.CurrentDomain;
            var currentName = currentDomain.FriendlyName;
            var pos = currentName.IndexOf('-');
            if (pos > 0) currentName = currentName.Substring(0, pos);
            
            var text = new System.Text.StringBuilder();
            text.Append("<div class=\"block\">Process ID: " + Process.GetCurrentProcess().Id + "</div>");
            text.Append("<div class=\"block\">");
            text.Append("<div>IIS Site: " + HostingEnvironment.ApplicationHost.GetSiteName() + "</div>");
            text.Append("<div>App ID: " + currentName + "</div>");
            //text.Append("<div>AppPool: " + Zbu.WebManagement.AppPoolHelper.GetCurrentApplicationPoolName() + "</div>");
            text.Append("</div>");
            
            text.Append("<div class=\"block\">Domains:<ul>");
            text.Append("<li>Not implemented.</li>");
            /*
            foreach (var domain in Zbu.WebManagement.AppDomainHelper.GetAppDomains().OrderBy(x => x.Id))
            {
                var name = domain.FriendlyName;
                pos = name.IndexOf('-');
                if (pos > 0) name = name.Substring(0, pos);
                text.Append("<li style=\""
                    + (name != currentName ? "color: #cccccc;" : "")
                    //+ (domain.Id == currentDomain.Id ? "" : "")
                    + "\">"
                    +"[" + domain.Id + "] " + name 
                    + (domain.IsDefaultAppDomain() ? " (default)" : "") 
                    + (domain.Id == currentDomain.Id ? " (current)" : "")
                    + "</li>");
            }
            */
            text.Append("</ul></div>");
            
            return ContentHtml(text.ToString());
        }
        
        public ActionResult Recycle()
        {
            return ContentHtml("Not implemented&mdash;please use IIS console.");
        }

        private static Template ImportTemplate(ServiceContext svces, string filepath, string name, string alias, string text, ITemplate master = null)
        {
            var t = new Template(filepath, name, alias) { Content = text };
            if (master != null)
                t.SetMasterTemplate(master);
            svces.FileService.SaveTemplate(t);
            return t;
        }
    }

    public class Startup : ApplicationEventHandler
    {
        protected override void ApplicationStarted(UmbracoApplicationBase umbracoApplication, ApplicationContext applicationContext)
        {
            base.ApplicationStarted(umbracoApplication, applicationContext);

            RouteTable.Routes.MapRoute(
               name: "LoadTest",
               //url: "umbraco/backoffice/zbqrtbnk/LoadTest/{action}";
			   url: "LoadTest/{action}",
               defaults: new
               {
                   controller = "LoadTest",
                   action = "Index"
               },
               namespaces: new[] { "Zbu.LoadTest" }
           );
        }
    }
}
