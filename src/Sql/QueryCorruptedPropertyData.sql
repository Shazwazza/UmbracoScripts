--This will show all property's that are storing data in more than one field type which is not supported
SELECT cmsPropertyType.id, cmsPropertyType.Alias, cmsDataType.dbType, cmsPropertyData.* FROM cmsPropertyType 
INNER JOIN cmsDataType ON cmsPropertyType.dataTypeId = cmsDataType.nodeId
INNER JOIN cmsPropertyData ON cmsPropertyType.id = cmsPropertyData.propertytypeid
WHERE 
(cmsPropertyData.dataNtext IS NOT NULL AND cmsPropertyData.dataDate IS NOT NULL) OR
(cmsPropertyData.dataNtext IS NOT NULL AND cmsPropertyData.dataNvarchar IS NOT NULL) OR
(cmsPropertyData.dataNtext IS NOT NULL AND cmsPropertyData.dataInt IS NOT NULL) OR
(cmsPropertyData.dataInt IS NOT NULL AND cmsPropertyData.dataDate IS NOT NULL) OR
(cmsPropertyData.dataInt IS NOT NULL AND cmsPropertyData.dataNvarchar IS NOT NULL) OR
(cmsPropertyData.dataNvarchar IS NOT NULL AND cmsPropertyData.dataDate IS NOT NULL)