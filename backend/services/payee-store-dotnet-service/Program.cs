using Microsoft.EntityFrameworkCore;
using PayeeService.Data;
using PayeeService.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using System.Text;
using Elastic.Apm.NetCoreAll;

var builder = WebApplication.CreateBuilder(args);

// Initialize comprehensive APM configuration (matching RUM observability level)
Console.WriteLine("🔧 Initializing comprehensive APM configuration for .NET Payee service...");

// Set comprehensive APM environment variables for maximum observability
Environment.SetEnvironmentVariable("ELASTIC_APM_SERVICE_NAME", Environment.GetEnvironmentVariable("ELASTIC_APM_SERVICE_NAME") ?? "payee-store-dotnet-service");
Environment.SetEnvironmentVariable("ELASTIC_APM_SERVICE_VERSION", Environment.GetEnvironmentVariable("ELASTIC_APM_SERVICE_VERSION") ?? "1.0.0");
Environment.SetEnvironmentVariable("ELASTIC_APM_ENVIRONMENT", Environment.GetEnvironmentVariable("ELASTIC_APM_ENVIRONMENT") ?? "production");
Environment.SetEnvironmentVariable("ELASTIC_APM_SERVER_URLS", Environment.GetEnvironmentVariable("ELASTIC_APM_SERVER_URLS") ?? "http://91.203.133.240:30200");

// Sampling configuration (100% like RUM)
Environment.SetEnvironmentVariable("ELASTIC_APM_TRANSACTION_SAMPLE_RATE", Environment.GetEnvironmentVariable("ELASTIC_APM_TRANSACTION_SAMPLE_RATE") ?? "1.0");
Environment.SetEnvironmentVariable("ELASTIC_APM_SPAN_SAMPLE_RATE", Environment.GetEnvironmentVariable("ELASTIC_APM_SPAN_SAMPLE_RATE") ?? "1.0");

// Data capture configuration (maximum like RUM)
Environment.SetEnvironmentVariable("ELASTIC_APM_CAPTURE_BODY", Environment.GetEnvironmentVariable("ELASTIC_APM_CAPTURE_BODY") ?? "all");
Environment.SetEnvironmentVariable("ELASTIC_APM_CAPTURE_HEADERS", Environment.GetEnvironmentVariable("ELASTIC_APM_CAPTURE_HEADERS") ?? "true");

// Distributed tracing configuration (matching RUM distributedTracingOrigins)
Environment.SetEnvironmentVariable("ELASTIC_APM_USE_DISTRIBUTED_TRACING", Environment.GetEnvironmentVariable("ELASTIC_APM_USE_DISTRIBUTED_TRACING") ?? "true");
Environment.SetEnvironmentVariable("ELASTIC_APM_SPAN_FRAMES_MIN_DURATION", Environment.GetEnvironmentVariable("ELASTIC_APM_SPAN_FRAMES_MIN_DURATION") ?? "0ms");

// Advanced configuration for maximum observability
Environment.SetEnvironmentVariable("ELASTIC_APM_LOG_LEVEL", Environment.GetEnvironmentVariable("ELASTIC_APM_LOG_LEVEL") ?? "Info");
Environment.SetEnvironmentVariable("ELASTIC_APM_RECORDING", Environment.GetEnvironmentVariable("ELASTIC_APM_RECORDING") ?? "true");
Environment.SetEnvironmentVariable("ELASTIC_APM_STACK_TRACE_LIMIT", Environment.GetEnvironmentVariable("ELASTIC_APM_STACK_TRACE_LIMIT") ?? "50");
Environment.SetEnvironmentVariable("ELASTIC_APM_SPAN_STACK_TRACE_MIN_DURATION", Environment.GetEnvironmentVariable("ELASTIC_APM_SPAN_STACK_TRACE_MIN_DURATION") ?? "0ms");

// Performance monitoring settings (.NET specific)
Environment.SetEnvironmentVariable("ELASTIC_APM_DISABLE_METRICS", Environment.GetEnvironmentVariable("ELASTIC_APM_DISABLE_METRICS") ?? "false");
Environment.SetEnvironmentVariable("ELASTIC_APM_METRICS_INTERVAL", Environment.GetEnvironmentVariable("ELASTIC_APM_METRICS_INTERVAL") ?? "30s");
Environment.SetEnvironmentVariable("ELASTIC_APM_MAX_QUEUE_SIZE", Environment.GetEnvironmentVariable("ELASTIC_APM_MAX_QUEUE_SIZE") ?? "1000");
Environment.SetEnvironmentVariable("ELASTIC_APM_FLUSH_INTERVAL", Environment.GetEnvironmentVariable("ELASTIC_APM_FLUSH_INTERVAL") ?? "1s");
Environment.SetEnvironmentVariable("ELASTIC_APM_TRANSACTION_MAX_SPANS", Environment.GetEnvironmentVariable("ELASTIC_APM_TRANSACTION_MAX_SPANS") ?? "500");

// .NET-specific comprehensive monitoring
Environment.SetEnvironmentVariable("ELASTIC_APM_PROFILING_INFERRED_SPANS_ENABLED", Environment.GetEnvironmentVariable("ELASTIC_APM_PROFILING_INFERRED_SPANS_ENABLED") ?? "true");
Environment.SetEnvironmentVariable("ELASTIC_APM_PROFILING_INFERRED_SPANS_MIN_DURATION", Environment.GetEnvironmentVariable("ELASTIC_APM_PROFILING_INFERRED_SPANS_MIN_DURATION") ?? "0ms");
Environment.SetEnvironmentVariable("ELASTIC_APM_APPLICATION_PACKAGES", Environment.GetEnvironmentVariable("ELASTIC_APM_APPLICATION_PACKAGES") ?? "PayeeService");

Console.WriteLine("✅ APM Configuration Applied:");
Console.WriteLine($"   Service: {Environment.GetEnvironmentVariable("ELASTIC_APM_SERVICE_NAME")} v{Environment.GetEnvironmentVariable("ELASTIC_APM_SERVICE_VERSION")} ({Environment.GetEnvironmentVariable("ELASTIC_APM_ENVIRONMENT")})");
Console.WriteLine($"   Server: {Environment.GetEnvironmentVariable("ELASTIC_APM_SERVER_URLS")}");
Console.WriteLine("   Sampling: 100% transactions, 100% spans");
Console.WriteLine("   Features: Entity Framework monitoring, HTTP tracing, database queries");
Console.WriteLine("   Monitoring: Maximum observability matching RUM frontend");

// Add services to the container
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Add comprehensive Elastic APM with all instrumentations
builder.Services.AddAllElasticApm();

// Database configuration
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection") 
    ?? "Host=localhost;Port=5432;Database=vubank_db;Username=vubank_user;Password=vubank_pass;";

builder.Services.AddDbContext<PayeeDbContext>(options =>
    options.UseNpgsql(connectionString)
           .EnableSensitiveDataLogging()  // Shows parameter values
           .LogTo(Console.WriteLine, LogLevel.Information)); // Logs SQL to console

// Register services
builder.Services.AddScoped<IPayeeService, PayeeService.Services.PayeeService>();
builder.Services.AddScoped<IIfscService, IfscService>();
builder.Services.AddHttpClient<IIfscService, IfscService>();

// JWT Authentication
var jwtSecret = Environment.GetEnvironmentVariable("JWT_SECRET") ?? 
                builder.Configuration["JWT_SECRET"] ?? 
                "vubank-super-secret-jwt-key-2023";
var key = Encoding.ASCII.GetBytes(jwtSecret);

builder.Services.AddAuthentication(x =>
{
    x.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    x.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(x =>
{
    x.RequireHttpsMetadata = false;
    x.SaveToken = true;
    x.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(key),
        ValidateIssuer = true,
        ValidIssuer = "vubank-login-service",
        ValidateAudience = false,
        ClockSkew = TimeSpan.Zero
    };
});

// Enhanced CORS configuration with comprehensive distributed tracing headers
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowVuBankOrigins",
        policy =>
        {
            policy.WithOrigins("http://localhost:3001", "http://localhost:3000", 
                             "http://localhost:8000", "http://localhost:8001", 
                             "http://localhost:8002", "http://localhost:8003", 
                             "http://localhost:8004", "http://localhost:8005",
                             "http://91.203.133.240:30200")
                  .AllowAnyMethod()
                  .AllowCredentials()
                  .WithHeaders("Origin", "X-Requested-With", "Content-Type", "Accept", 
                             "Authorization", "X-Api-Client", "X-Request-ID", 
                             "traceparent", "tracestate", "elastic-apm-traceparent")
                  .WithExposedHeaders("X-Service-Name", "X-Service-Version", 
                                    "traceparent", "tracestate", "elastic-apm-traceparent");
        });
});

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors("AllowVuBankOrigins");
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

// Ensure database is created and seeded
using (var scope = app.Services.CreateScope())
{
    var context = scope.ServiceProvider.GetRequiredService<PayeeDbContext>();
    await context.Database.EnsureCreatedAsync();
}

// Health check endpoint
app.MapGet("/health", () => {
    var apmServerUrl = Environment.GetEnvironmentVariable("ELASTIC_APM_SERVER_URLS") ?? "not configured";
    var serviceName = Environment.GetEnvironmentVariable("ELASTIC_APM_SERVICE_NAME") ?? "payee-store-service";
    var environment = Environment.GetEnvironmentVariable("ELASTIC_APM_ENVIRONMENT") ?? "production";
    
    return Results.Ok(new { 
        status = "healthy",
        service = "Payee Store Service",
        version = "1.0.0",
        timestamp = DateTime.UtcNow,
        apm = new {
            enabled = !string.IsNullOrEmpty(Environment.GetEnvironmentVariable("ELASTIC_APM_SERVER_URLS")),
            serverUrl = apmServerUrl,
            serviceName = serviceName,
            environment = environment
        }
    });
});

app.Run();