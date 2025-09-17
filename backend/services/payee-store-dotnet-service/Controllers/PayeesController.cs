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
                    return Unauthorized("User ID not found in token");

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
                if (!ModelState.IsValid)
                    return BadRequest(ModelState);

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
                   User.FindFirst("sub")?.Value;
        }
    }

    // Health check controller for container monitoring
    [ApiController]
    [Route("api/[controller]")]
    public class HealthController : ControllerBase
    {
        private readonly PayeeService.Data.PayeeDbContext _context;

        public HealthController(PayeeService.Data.PayeeDbContext context)
        {
            _context = context;
        }

        [HttpGet]
        public async Task<IActionResult> Get()
        {
            try
            {
                // Check database connectivity
                await _context.Database.CanConnectAsync();
                return Ok(new { 
                    status = "healthy", 
                    timestamp = DateTime.UtcNow,
                    service = "payee-service",
                    version = "1.0.0"
                });
            }
            catch (Exception ex)
            {
                return StatusCode(503, new { 
                    status = "unhealthy", 
                    timestamp = DateTime.UtcNow,
                    error = ex.Message 
                });
            }
        }
    }
}