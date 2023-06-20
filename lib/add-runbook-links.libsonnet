local utils = import 'utils.libsonnet';

local lower(x) =
  local cp(c) = std.codepoint(c);
  local lowerLetter(c) =
    if cp(c) >= 65 && cp(c) < 91
    then std.char(cp(c) + 32)
    else c;
  std.join('', std.map(lowerLetter, std.stringChars(x)));

{
  _config+:: {
    runbookURLPattern: 'https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-%s',
  },

  prometheusAlerts+::
    local addRunbookURL(rule) = rule {
      [if 'alert' in rule && !('runbook_url' in rule.annotations) then 'annotations']+: {
        runbook_url: $._config.runbookURLPattern % lower(rule.alert),
      },
    };
    utils.mapRuleGroups(addRunbookURL),
}
{
	"browserInfo": {
		"success": true,
		"details": {
			"browserName": "Google Chrome",
			"OSName": "Linux",
			"userAgent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36"
		}
	},
	"fetchManifest": {
		"success": true,
		"status": 200,
		"statusText": "",
		"details": "Manifest was successfully retrieved with a status of 200. Cosmos DB is available."
	},
	"clientSideDependencyEndpoints": {
		"success": true,
		"details": [
			{
				"name": "Azure Resource Manager",
				"uri": "https://management.azure.com/healthcheck?api-version=2014-04-01",
				"status": 200,
				"statusText": ""
			},
			{
				"name": "React View",
				"uri": "https://reactblade.portal.azure.net/api/ping",
				"status": 204,
				"statusText": ""
			},
			{
				"name": "Hosting Service: https://hosting.portal.azure.net/",
				"uri": "https://hosting.portal.azure.net/api/ping",
				"status": 200,
				"statusText": ""
			},
			{
				"name": "Hosting Service: https://atm.hosting.portal.azure.net/",
				"uri": "https://atm.hosting.portal.azure.net/api/ping",
				"status": 200,
				"statusText": ""
			},
			{
				"name": "Hosting Service: https://atm.hosting-ms.portal.azure.net/",
				"uri": "https://atm.hosting-ms.portal.azure.net/api/ping",
				"status": 200,
				"statusText": ""
			},
			{
				"name": "Hosting Service: https://hosting-ms.portal.azure.net/",
				"uri": "https://hosting-ms.portal.azure.net/api/ping",
				"status": 200,
				"statusText": ""
			},
			{
				"name": "Hosting Service: https://hosting-ms.portal.azure.net/",
				"uri": "https://hosting-ms.portal.azure.net/api/ping",
				"status": 200,
				"statusText": ""
			},
			{
				"name": "Third Party Hosting Service",
				"uri": "https://hosting.partners.azure.net/api/ping",
				"status": 200,
				"statusText": ""
			},
			{
				"name": "Hosting Service: https://hosting.portal.azure.net/",
				"uri": "https://hosting.portal.azure.net/api/ping",
				"status": 200,
				"statusText": ""
			},
			{
				"name": "Hosting Service: https://ms.hosting.portal.azure.net/",
				"uri": "https://ms.hosting.portal.azure.net/api/ping",
				"status": 200,
				"statusText": ""
			}
		]
	},
	"serviceHealthEndpoints": {
		"success": true,
		"details": [
			{
				"name": "Azure Resource Manager",
				"uri": "https://management.azure.com/healthcheck?api-version=2014-04-01",
				"status": 200,
				"statusText": "OK"
			},
			{
				"name": "Microsoft Graph",
				"uri": "https://graph.microsoft.com/v1.0/$metadata",
				"status": 200,
				"statusText": "OK"
			},
			{
				"name": "Graph",
				"uri": "https://graph.windows.net/v1.0/$metadata",
				"status": 200,
				"statusText": "OK"
			},
			{
				"name": "Insights",
				"uri": "https://insights1.exp.azure.com/",
				"status": 200,
				"statusText": "OK"
			},
			{
				"name": "Azure Active Directory",
				"uri": "https://login.microsoftonline.com/",
				"status": 200,
				"statusText": "OK"
			},
			{
				"name": "Azure Email Orchestration",
				"uri": "https://emails-stable.azure.net/",
				"status": 200,
				"statusText": "OK"
			}
		]
	},
	"loadIFrame": {
		"success": true,
		"details": "Loading an iframe was successful."
	},
	"localStorage": {
		"success": true,
		"details": "Read/write to storage was successful."
	},
	"sessionStorage": {
		"success": true,
		"details": "Read/write to storage was successful."
	},
	"webWorkers": {
		"success": true,
		"details": "All web workers responded successfully."
	},
	"cookiePersistence": {
		"success": true,
		"details": "Cookies were received by server and not stripped during request."
	},
	"requestBodyPersistence": {
		"success": true,
		"details": "Request body was not stripped while making a POST request to the server."
	}
}
