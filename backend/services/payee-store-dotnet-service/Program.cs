using Microsoft.EntityFrameworkCore;
using PayeeService.Data;
using PayeeService.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using System.Text;
using Elastic.Apm.NetCoreAll;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Add Elastic APM
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

// CORS configuration
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowVuBankOrigins",
        policy =>
        {
            policy.WithOrigins("http://localhost:3001", "http://localhost:3000")
                  .AllowAnyHeader()
                  .AllowAnyMethod()
                  .AllowCredentials();
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