<Query Kind="Statements">
  <Connection>
    <ID>96c5d150-f440-4496-b12e-479e61869702</ID>
    <Persist>true</Persist>
    <Driver Assembly="UmbracoLinqPad" PublicKeyToken="977d3d694b4b0d0b">UmbracoLinqPad.UmbracoDynamicDriver</Driver>
    <AppConfigPath>X:\Projects\~WebSitesTesting\CourierTest1\CourierTest1</AppConfigPath>
  </Connection>
</Query>

var contentXmlFile = new FileInfo("X:\\TEMP\\umbraco.config");
if (!contentXmlFile.Exists)
	throw new InvalidOperationException("No file found");

var contentService = ApplicationContext.Services.ContentService;

var xmlDocument = XDocument.Load(contentXmlFile.FullName);
foreach (var xmlContentItem in xmlDocument.Root.XPathSelectElements("//*[@isDoc]"))
{
	var id = int.Parse(xmlContentItem.Attribute("id").Value);
	("Processing xml content item ID " + id).Dump();
	
	var found = contentService.GetById(id);
	if (found == null)
	{
		("No content found by id " + id).Dump();
		continue;
	}
	
	foreach (var xmlProperty in xmlContentItem.XPathSelectElements("/*[not(@isDoc)]"))
	{
		var propertyAlias = xmlProperty.Name.LocalName;
		("Processing property with alias " + propertyAlias).Dump();
		
		found.SetValue(propertyAlias, xmlProperty.Value);
	}
	
	"Saving content item".Dump();
	
	var result = contentService.SaveAndPublishWithStatus(found);
	
	result.Result.Dump();
}