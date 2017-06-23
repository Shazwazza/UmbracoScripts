<Query Kind="Statements">
  <Reference>&lt;RuntimeDirectory&gt;\System.Net.Http.dll</Reference>
  <Namespace>System.Net.Http</Namespace>
</Query>

var url = "http://local-shantest-carlsberg-group.rainbowsrock.net/umbraco/Upgrades/MinorVersionUpgradeService/PostPerformRebuild ";
//var url = "http://local-shantest-carlsberg-group.rainbowsrock.net/umbraco/Upgrades/MinorVersionUpgradeService/PostPerformSoftRebuild ";
var _httpClient = new System.Net.Http.HttpClient();

var byteArray = Encoding.ASCII.GetBytes(string.Format("{0}:{1}", "shannon@umbraco.com", "L!GsCCecl24IEE!L"));
var header = new System.Net.Http.Headers.AuthenticationHeaderValue("Basic", Convert.ToBase64String(byteArray));

_httpClient.DefaultRequestHeaders.Authorization = header;
_httpClient.DefaultRequestHeaders.TryAddWithoutValidation("Content-Type", "application/json; charset=utf-8");
_httpClient.DefaultRequestHeaders.Add("X-UmbracoCoreMinorVersionUpgrade", "Hello");

var response = await _httpClient.PostAsync(url, null);
response.Dump();