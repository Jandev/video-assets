// =============================================================================
// Contoso Widget Platform - Log Alerts demo API
// =============================================================================
// A tiny widget-catalog / orders API whose only job is to emit realistic
// telemetry into Application Insights so the log-alert rules have something to
// fire on:
//
//   - normal traffic on /health, /widgets and /orders  -> AppRequests
//   - GET /widgets/boom     returns 500                 -> AppRequests (5xx)
//   - GET /orders/secret    returns 401/403             -> AppRequests (auth)
//   - GET /widgets/supplier calls a dead dependency     -> AppDependencies fail
//
// The Azure Monitor OpenTelemetry distro (AddAzureMonitor) does all the
// instrumentation. Set APPLICATIONINSIGHTS_CONNECTION_STRING and it exports;
// leave it unset and the app still runs so you can drive it locally.
// =============================================================================

using System.Diagnostics;
using Azure.Monitor.OpenTelemetry.AspNetCore;
using OpenTelemetry.Resources;

var builder = WebApplication.CreateBuilder(args);

// AppRoleName in Log Analytics comes from the OpenTelemetry service.name
// resource attribute. The alert queries filter on this exact value, so it is
// the contract between the app and the rules.
const string ServiceName = "contoso-widget-api";

var connectionString = builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"]
    ?? Environment.GetEnvironmentVariable("APPLICATIONINSIGHTS_CONNECTION_STRING");

var otel = builder.Services.AddOpenTelemetry();
otel.ConfigureResource(resource => resource.AddService(
    serviceName: ServiceName,
    serviceVersion: "1.0.0"));

if (!string.IsNullOrWhiteSpace(connectionString))
{
    // One call turns on request, dependency, metric and log collection and
    // points it all at Application Insights.
    otel.UseAzureMonitor(options => options.ConnectionString = connectionString);
}

// A named HttpClient used by the failure-injection endpoint. It points at an
// address that never answers, which is what produces a FAILED AppDependencies
// row - the signal the dependency-failures rule counts.
builder.Services.AddHttpClient("supplier", client =>
{
    client.BaseAddress = new Uri("https://supplier.invalid.contoso.example/");
    client.Timeout = TimeSpan.FromSeconds(2);
});

var app = builder.Build();

// Turn the injected exception below into a real HTTP 500 (recorded in
// AppRequests as ResultCode 500) rather than a developer exception page.
// Registered before the endpoints so it wraps them.
app.UseExceptionHandler(errorApp =>
    errorApp.Run(context =>
    {
        context.Response.StatusCode = StatusCodes.Status500InternalServerError;
        Activity.Current?.SetStatus(ActivityStatusCode.Error);
        return context.Response.WriteAsync("Internal Server Error");
    }));

var widgets = new[]
{
    new Widget("WIDGET-001", "Standard Widget", 9.99m, 512),
    new Widget("WIDGET-002", "Reinforced Widget", 14.50m, 128),
    new Widget("WIDGET-003", "Compact Widget", 4.25m, 1024),
};

// -----------------------------------------------------------------------------
// Healthy endpoints - normal AppRequests traffic
// -----------------------------------------------------------------------------
app.MapGet("/health", () => Results.Ok(new { status = "healthy", service = ServiceName }));

app.MapGet("/widgets", () => Results.Ok(widgets));

app.MapGet("/widgets/{id}", (string id) =>
{
    var widget = Array.Find(widgets, w => w.Id.Equals(id, StringComparison.OrdinalIgnoreCase));
    return widget is null ? Results.NotFound(new { id }) : Results.Ok(widget);
});

app.MapPost("/orders", (OrderRequest order) =>
{
    // No customer data is logged: only a synthetic order id and a line count.
    var orderId = $"ORD-{Random.Shared.Next(1, 99_999_999):D8}";
    app.Logger.LogInformation(
        "Accepted order {OrderId} with {LineCount} line(s)", orderId, order.Lines.Count);
    return Results.Created($"/orders/{orderId}", new { orderId, lines = order.Lines.Count });
});

// -----------------------------------------------------------------------------
// Failure-injection endpoints - so a rule can actually be made to fire
// -----------------------------------------------------------------------------

// 500: drives AppRequests | ResultCode >= 500 -> server-errors rule.
app.MapGet("/widgets/boom", () =>
{
    throw new InvalidOperationException("Injected server error for the server-errors alert rule.");
});

// 401/403: drives AppRequests | ResultCode in (401,403) -> authorization rule.
// A ?forbidden=true switches 401 -> 403 so you can show both.
app.MapGet("/orders/secret", (bool forbidden = false) =>
    forbidden
        ? Results.StatusCode(StatusCodes.Status403Forbidden)
        : Results.StatusCode(StatusCodes.Status401Unauthorized));

// Failed outbound dependency: drives AppDependencies | Success == false ->
// dependency-failures rule. The call to a dead host throws; we translate it
// into a 502 and let the OpenTelemetry dependency span record the failure.
app.MapGet("/widgets/{id}/supplier", async (string id, IHttpClientFactory factory) =>
{
    var client = factory.CreateClient("supplier");
    try
    {
        using var response = await client.GetAsync($"stock/{id}");
        return Results.Ok(new { id, inStock = response.IsSuccessStatusCode });
    }
    catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException)
    {
        app.Logger.LogWarning("Supplier stock lookup failed for {WidgetId}", id);
        return Results.StatusCode(StatusCodes.Status502BadGateway);
    }
});

app.Run();

internal sealed record Widget(string Id, string Name, decimal Price, int InStock);

internal sealed record OrderRequest(List<OrderLine> Lines);

internal sealed record OrderLine(string WidgetId, int Quantity);
