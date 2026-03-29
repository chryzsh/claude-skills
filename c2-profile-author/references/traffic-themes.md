# Traffic Theming Guide for Malleable C2 Profiles

## Table of Contents
- [Theme Selection](#theme-selection)
- [Theme Anatomy](#theme-anatomy)
- [Theme Examples](#theme-examples)
- [Anti-Patterns](#anti-patterns)

---

## Theme Selection

Pick a cloud/SaaS service whose traffic is expected in the target environment:

| Category | Services |
|---|---|
| Microsoft | Azure API, Exchange Online, OneDrive sync, SharePoint, Teams |
| Google | Analytics, GCP API, Drive, Workspace |
| CDN/Edge | Cloudflare, Akamai, Fastly, AWS CloudFront |
| SaaS | Slack API, Salesforce, ServiceNow, Okta |

**Selection criteria:**
- What cloud services does the target org use?
- Which services generate high-volume background traffic (sync, telemetry)?
- Which services use JSON APIs (easy to wrap C2 data in)?

---

## Theme Anatomy

A complete theme touches every network-visible element:

### 1. Server Response Header
Match the `Server` header to the real service:
- Google: `gws`
- Cloudflare: `cloudflare`
- Microsoft IIS: `Microsoft-IIS/10.0`
- Apache (generic): `Apache/2.4.41`

### 2. Service-Specific Headers
Add headers the real service sends:
- Cloudflare: `CF-Ray`, `CF-Cache-Status`
- SharePoint: `SPRequestGuid`, `X-SharePointHealthScore`
- Exchange: `X-OWA-Version`, `X-CalculatedBETarget`, `X-MS-Exchange-Organization-AuthAs`
- Google: `Alt-Svc`, `X-Content-Type-Options`

### 3. URI Paths
Use realistic paths from the service's actual API:
- Exchange: `/api/v2.0/me/messages`, `/api/v2.0/me/sendmail`
- SharePoint: `/_api/v2.0/drives/delta`, `/_api/web/lists/Documents/items`
- GA: `/__utm.gif`, `/collect`, `/batch/analytics/v1`
- Cloudflare: `/cdn-cgi/rum`, `/client/v4/zones/events`

### 4. User-Agent
Match what would legitimately call the API:
- OneDrive sync: `Microsoft SkyDriveSync 24.005.0117.0002 ship; Windows NT 10.0 (19045)`
- Browser-based: modern Chrome/Edge UA
- API client: service-specific SDK UA

### 5. Response Wrapping
Wrap C2 data in the service's JSON/HTML structure:
```
# Exchange example
prepend "{\"@odata.context\":\"https://outlook.office365.com/api/v2.0/$metadata#Me/Messages\",\"value\":[{\"Id\":\"";
append "\"}]}\n";

# Google Analytics example
prepend "{\"kind\":\"analytics#data\",\"totalResults\":1,\"rows\":[[\"";
append "\"]]}\n";
```

### 6. Cookie/Metadata Transport
Use the service's actual cookie naming:
- Exchange: `X-OWA-CANARY=`
- SharePoint: `FedAuth=`
- Google: `SESSIONID=`
- Cloudflare: `__cflb=`

### 7. TLS Certificate
Match the service:
```
# Exchange
set CN "*.outlook.office365.com";
set O "Microsoft Corporation";

# Google
set CN "*.googleapis.com";
set O "Google LLC";

# Cloudflare
set CN "*.cloudflareapi.com";
set O "Cloudflare, Inc.";
```

---

## Theme Examples

### Microsoft Exchange / Outlook
- GET: `/api/v2.0/me/messages` with `$select`, `$top`, `$orderby` params
- POST: `/api/v2.0/me/sendmail` with JSON message body
- Server: `Microsoft-IIS/10.0`, `X-Powered-By: ASP.NET`
- Headers: `X-OWA-Version`, `X-CalculatedBETarget`
- Cookie: `X-OWA-CANARY=<base64url metadata>`
- UA: Chrome/Edge

### OneDrive / SharePoint
- GET: `/_api/v2.0/drives/delta` with `$select`, `token` params
- POST: `/_api/web/lists/Documents/items`
- Server: `Microsoft-IIS/10.0`, `X-MSDAVEXT_Error`
- Headers: `SPRequestGuid`, `X-SharePointHealthScore`
- Cookie: `FedAuth=<base64 metadata>; rtFa=true`
- UA: `Microsoft SkyDriveSync ...` (sync client)

### Google Analytics
- GET: `/__utm.gif` with GA params (`utmac`, `utmcn`, `utmcs`, `utmsr`)
- POST: `/batch/analytics/v1` with JSON events
- Server: `gws`
- Response: GIF89a header wrapping, or JSON `analytics#data`
- Cookie: `SESSIONID=<netbios metadata>`
- UA: Chrome

### Cloudflare CDN/API
- GET: `/cdn-cgi/rum` with performance params
- POST: `/client/v4/zones/events` with JSON
- Server: `cloudflare`
- Headers: `CF-Ray`, `CF-Cache-Status`, `CF-Request-ID`
- Cookie: `__cflb=<base64 metadata>`
- UA: Chrome

---

## Anti-Patterns

- **Don't use URIs from publicly available profiles** - they are signatured by defenders
- **Don't mix themes** - Google headers with Microsoft URIs is an instant red flag
- **Don't reuse the same theme** across profiles meant to simulate different actors
- **Don't use placeholder values** like `ytrewq.com`, `FooCorp`, `header-1` (from reference profile)
- **Don't use the reference profile's URIs** (`/api/v1/Updates`, `/api/v1/Telemetry/Id/`)
- **Don't use outdated UAs** - IE11/Trident stands out in modern environments
