using Microsoft.EntityFrameworkCore;
using PayeeService.Data;
using PayeeService.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Database configuration
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection") 
    ?? "Host=localhost;Port=5432;Database=vubank_db;Username=vubank_user;Password=vubank_pass;";

builder.Services.AddDbContext<PayeeDbContext>(options =>
    options.UseNpgsql(connectionString));

// Register services
builder.Services.AddScoped<IPayeeService, PayeeService.Services.PayeeService>();
builder.Services.AddScoped<IIfscService, IfscService>();
builder.Services.AddHttpClient<IIfscService, IfscService>();

// JWT Authentication
var jwtSecret = builder.Configuration["JWT_SECRET"] ?? "your-super-secret-jwt-key-for-vubank-application";
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
app.MapGet("/health", () => Results.Ok(new { 
    status = "healthy",
    service = "Payee Store Service",
    version = "1.0.0",
    timestamp = DateTime.UtcNow 
}));

app.Run();