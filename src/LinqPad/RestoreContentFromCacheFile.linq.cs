
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
	
	foreach (var xmlProperty in xmlContentItem.XPathSelectElements("./*[not(@isDoc)]"))
	{
		var propertyAlias = xmlProperty.Name.LocalName;
		("Processing property with alias " + propertyAlias).Dump();
		
		found.SetValue(propertyAlias, xmlProperty.Value);
	}
	
	"Saving content item".Dump();
	
	var result = contentService.SaveAndPublishWithStatus(found);
	
	result.Result.Dump();
}
