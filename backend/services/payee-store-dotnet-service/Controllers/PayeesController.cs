using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PayeeService.Models.DTOs;
using PayeeService.Services;
using System.Security.Claims;

namespace PayeeService.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class PayeesController : ControllerBase
    {
        private readonly IPayeeService _payeeService;
        private readonly ILogger<PayeesController> _logger;

        public PayeesController(IPayeeService payeeService, ILogger<PayeesController> logger)
        {
            _payeeService = payeeService;
            _logger = logger;
        }

        /// <summary>
        /// Get all payees for the authenticated user
        /// </summary>
        [HttpGet]
        public async Task<ActionResult<IEnumerable<PayeeResponse>>> GetPayees()
        {
            try
            {
                var userId = GetUserId();
                if (string.IsNullOrEmpty(userId))
                {
                    return Unauthorized("User ID not found in token");
                }

                var payees = await _payeeService.GetPayeesByUserIdAsync(userId);
                
                return Ok(payees);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving payees");
                return StatusCode(500, new { message = "An error occurred while retrieving payees" });
            }
        }

        /// <summary>
        /// Get a specific payee by ID
        /// </summary>
        [HttpGet("{id}")]
        public async Task<ActionResult<PayeeResponse>> GetPayee(int id)
        {
            try
            {
                var userId = GetUserId();
                if (string.IsNullOrEmpty(userId))
                    return Unauthorized("User ID not found in token");

                var payee = await _payeeService.GetPayeeByIdAsync(id, userId);
                if (payee == null)
                    return NotFound(new { message = "Payee not found" });

                return Ok(payee);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error retrieving payee {id}");
                return StatusCode(500, new { message = "An error occurred while retrieving the payee" });
            }
        }

        /// <summary>
        /// Add a new payee
        /// </summary>
        [HttpPost]
        public async Task<ActionResult<PayeeResponse>> AddPayee([FromBody] AddPayeeRequest request)
        {
            try
            {
                // Debug logging - log the raw request
                _logger.LogInformation($"AddPayee controller called");
                _logger.LogInformation($"Raw request PayeeName: '{request?.PayeeName}'");
                _logger.LogInformation($"Raw request BeneficiaryName: '{request?.BeneficiaryName}'");
                _logger.LogInformation($"Raw request AccountNumber: '{request?.AccountNumber}'");
                _logger.LogInformation($"Raw request IfscCode: '{request?.IfscCode}'");
                _logger.LogInformation($"Raw request AccountType: '{request?.AccountType}'");
                
                if (!ModelState.IsValid)
                {
                    _logger.LogWarning($"Model validation failed: {string.Join(", ", ModelState.Values.SelectMany(v => v.Errors).Select(e => e.ErrorMessage))}");
                    return BadRequest(ModelState);
                }

                var userId = GetUserId();
                if (string.IsNullOrEmpty(userId))
                    return Unauthorized("User ID not found in token");

                var payee = await _payeeService.AddPayeeAsync(request, userId);
                return CreatedAtAction(nameof(GetPayee), new { id = payee.Id }, payee);
            }
            catch (InvalidOperationException ex)
            {
                return Conflict(new { message = ex.Message });
            }
            catch (ArgumentException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error adding payee");
                return StatusCode(500, new { message = "An error occurred while adding the payee" });
            }
        }

        /// <summary>
        /// Delete a payee
        /// </summary>
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeletePayee(int id)
        {
            try
            {
                var userId = GetUserId();
                if (string.IsNullOrEmpty(userId))
                    return Unauthorized("User ID not found in token");

                var deleted = await _payeeService.DeletePayeeAsync(id, userId);
                if (!deleted)
                    return NotFound(new { message = "Payee not found" });

                return Ok(new { message = "Payee deleted successfully" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error deleting payee {id}");
                return StatusCode(500, new { message = "An error occurred while deleting the payee" });
            }
        }

        /// <summary>
        /// Check if a payee exists with given account details
        /// </summary>
        [HttpPost("exists")]
        public async Task<ActionResult<PayeeExistsResponse>> CheckPayeeExists([FromBody] CheckPayeeExistsRequest request)
        {
            try
            {
                if (!ModelState.IsValid)
                    return BadRequest(ModelState);

                var userId = GetUserId();
                if (string.IsNullOrEmpty(userId))
                    return Unauthorized("User ID not found in token");

                var exists = await _payeeService.PayeeExistsAsync(request.AccountNumber, request.IfscCode, userId);
                return Ok(new PayeeExistsResponse { Exists = exists });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error checking payee existence");
                return StatusCode(500, new { message = "An error occurred while checking payee existence" });
            }
        }

        private string? GetUserId()
        {
            return User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? 
                   User.FindFirst("userId")?.Value ?? 
                   User.FindFirst("user_id")?.Value ??
                   User.FindFirst("sub")?.Value;
        }
    }

    // Health check controller for container monitoring
    [ApiController]
    [Route("api/[controller]")]
    public class HealthController : ControllerBase
    {
        private readonly PayeeService.Data.PayeeDbContext _context;
        private readonly ILogger<HealthController> _logger;

        public HealthController(PayeeService.Data.PayeeDbContext context, ILogger<HealthController> logger)
        {
            _context = context;
            _logger = logger;
        }

        /// <summary>
        /// Comprehensive health check endpoint
        /// </summary>
        [HttpGet]
        public async Task<IActionResult> GetHealth()
        {
            try
            {
                var healthData = new
                {
                    status = "healthy",
                    service = "vubank-payee-service",
                    timestamp = DateTime.UtcNow.ToString("O"),
                    version = "1.0.0",
                    environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Production",
                    uptime = GetUptime(),
                    memory = GetMemoryInfo(),
                    dependencies = await GetDependenciesHealth()
                };

                _logger.LogDebug("Health check completed successfully");
                return Ok(healthData);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Health check failed");
                
                var unhealthyData = new
                {
                    status = "unhealthy",
                    service = "vubank-payee-service",
                    timestamp = DateTime.UtcNow.ToString("O"),
                    error = ex.Message
                };

                return StatusCode(503, unhealthyData);
            }
        }

        private static string GetUptime()
        {
            var uptime = DateTime.UtcNow - System.Diagnostics.Process.GetCurrentProcess().StartTime.ToUniversalTime();
            return $"{uptime.Days}d {uptime.Hours}h {uptime.Minutes}m {uptime.Seconds}s";
        }

        private static object GetMemoryInfo()
        {
            var process = System.Diagnostics.Process.GetCurrentProcess();
            return new
            {
                workingSet = FormatBytes(process.WorkingSet64),
                privateMemory = FormatBytes(process.PrivateMemorySize64),
                gcMemory = FormatBytes(GC.GetTotalMemory(false)),
                maxWorkingSet = FormatBytes(process.MaxWorkingSet.ToInt64())
            };
        }

        private async Task<object> GetDependenciesHealth()
        {
            var dependencies = new Dictionary<string, string>();

            // Check database connectivity
            try
            {
                var canConnect = await _context.Database.CanConnectAsync();
                dependencies["database"] = canConnect ? "healthy" : "unhealthy";
            }
            catch (Exception ex)
            {
                dependencies["database"] = $"unhealthy: {ex.Message}";
            }

            return dependencies;
        }

        private static string FormatBytes(long bytes)
        {
            if (bytes < 1024) return $"{bytes} B";
            if (bytes < 1024 * 1024) return $"{bytes / 1024:F1} KB";
            if (bytes < 1024 * 1024 * 1024) return $"{bytes / (1024 * 1024):F1} MB";
            return $"{bytes / (1024 * 1024 * 1024):F1} GB";
        }
    }
}