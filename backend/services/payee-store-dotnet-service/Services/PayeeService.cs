using Microsoft.EntityFrameworkCore;
using PayeeService.Data;
using PayeeService.Models;
using PayeeService.Models.DTOs;

namespace PayeeService.Services
{
    public interface IPayeeService
    {
        Task<IEnumerable<PayeeResponse>> GetPayeesByUserIdAsync(string userId);
        Task<PayeeResponse?> GetPayeeByIdAsync(int payeeId, string userId);
        Task<PayeeResponse> AddPayeeAsync(AddPayeeRequest request, string userId);
        Task<bool> DeletePayeeAsync(int payeeId, string userId);
        Task<bool> PayeeExistsAsync(string accountNumber, string ifscCode, string userId);
    }

    public class PayeeService : IPayeeService
    {
        private readonly PayeeDbContext _context;
        private readonly IIfscService _ifscService;
        private readonly ILogger<PayeeService> _logger;

        public PayeeService(PayeeDbContext context, IIfscService ifscService, ILogger<PayeeService> logger)
        {
            _context = context;
            _ifscService = ifscService;
            _logger = logger;
        }

        public async Task<IEnumerable<PayeeResponse>> GetPayeesByUserIdAsync(string userId)
        {
            try
            {
                var payees = await _context.Payees
                    .Where(p => p.UserId == userId)
                    .OrderBy(p => p.PayeeName)
                    .ToListAsync();

                return payees.Select(p => new PayeeResponse
                {
                    Id = p.Id,
                    PayeeName = p.PayeeName,
                    AccountNumber = p.AccountNumber,
                    IfscCode = p.IfscCode,
                    BankName = p.BankName,
                    BranchName = p.BranchName,
                    AccountType = p.AccountType,
                    City = p.City,
                    State = p.State,
                    BranchAddress = p.BranchAddress,
                    ContactNumber = p.ContactNumber,
                    MicrCode = p.MicrCode,
                    BankCode = p.BankCode,
                    RtgsEnabled = p.RtgsEnabled,
                    NeftEnabled = p.NeftEnabled,
                    ImpsEnabled = p.ImpsEnabled,
                    UpiEnabled = p.UpiEnabled,
                    CreatedAt = p.CreatedAt,
                    UpdatedAt = p.UpdatedAt
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error retrieving payees for user: {userId}");
                throw;
            }
        }

        public async Task<PayeeResponse?> GetPayeeByIdAsync(int payeeId, string userId)
        {
            try
            {
                var payee = await _context.Payees
                    .FirstOrDefaultAsync(p => p.Id == payeeId && p.UserId == userId);

                if (payee == null)
                    return null;

                return new PayeeResponse
                {
                    Id = payee.Id,
                    PayeeName = payee.PayeeName,
                    AccountNumber = payee.AccountNumber,
                    IfscCode = payee.IfscCode,
                    BankName = payee.BankName,
                    BranchName = payee.BranchName,
                    AccountType = payee.AccountType,
                    City = payee.City,
                    State = payee.State,
                    BranchAddress = payee.BranchAddress,
                    ContactNumber = payee.ContactNumber,
                    MicrCode = payee.MicrCode,
                    BankCode = payee.BankCode,
                    RtgsEnabled = payee.RtgsEnabled,
                    NeftEnabled = payee.NeftEnabled,
                    ImpsEnabled = payee.ImpsEnabled,
                    UpiEnabled = payee.UpiEnabled,
                    CreatedAt = payee.CreatedAt,
                    UpdatedAt = payee.UpdatedAt
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error retrieving payee {payeeId} for user: {userId}");
                throw;
            }
        }

        public async Task<PayeeResponse> AddPayeeAsync(AddPayeeRequest request, string userId)
        {
            try
            {
                // Debug logging - log the incoming request
                _logger.LogInformation($"AddPayeeAsync called for user: {userId}");
                _logger.LogInformation($"Request PayeeName: '{request.PayeeName}'");
                _logger.LogInformation($"Request BeneficiaryName: '{request.BeneficiaryName}'");
                _logger.LogInformation($"Request AccountNumber: '{request.AccountNumber}'");
                _logger.LogInformation($"Request IfscCode: '{request.IfscCode}'");
                _logger.LogInformation($"Request AccountType: '{request.AccountType}'");

                // Validate that we have a non-empty payee name
                if (string.IsNullOrWhiteSpace(request.PayeeName))
                {
                    throw new ArgumentException("Payee name is required and cannot be empty");
                }

                // Sanitize inputs
                var sanitizedPayeeName = request.PayeeName.Trim();
                var sanitizedAccountNumber = request.AccountNumber?.Trim() ?? string.Empty;
                var sanitizedIfscCode = request.IfscCode?.Trim()?.ToUpper() ?? string.Empty;
                var sanitizedAccountType = request.AccountType?.Trim() ?? "Savings";
                
                // Check if payee already exists
                var existingPayee = await _context.Payees
                    .FirstOrDefaultAsync(p => p.UserId == userId && 
                                            p.AccountNumber == sanitizedAccountNumber && 
                                            p.IfscCode == sanitizedIfscCode);

                if (existingPayee != null)
                {
                    throw new InvalidOperationException("Payee with this account number and IFSC code already exists");
                }

                // Validate IFSC code
                var ifscValidation = await _ifscService.ValidateIfscAsync(sanitizedIfscCode);
                if (!ifscValidation.IsValid)
                {
                    throw new ArgumentException($"Invalid IFSC code: {ifscValidation.ErrorMessage}");
                }

                // Create new payee with enhanced fields from IFSC validation
                var payee = new Payee
                {
                    UserId = userId,
                    PayeeName = sanitizedPayeeName,
                    BeneficiaryName = sanitizedPayeeName, // Use the same value for backward compatibility
                    AccountNumber = sanitizedAccountNumber,
                    IfscCode = sanitizedIfscCode,
                    BankName = ifscValidation.BankName ?? "Unknown Bank",
                    BranchName = ifscValidation.BranchName ?? "Unknown Branch",
                    AccountType = sanitizedAccountType,
                    City = ifscValidation.City,
                    State = ifscValidation.State,
                    BranchAddress = ifscValidation.Address,
                    ContactNumber = ifscValidation.Contact,
                    MicrCode = ifscValidation.MicrCode,
                    BankCode = ifscValidation.BankCode,
                    RtgsEnabled = ifscValidation.RtgsSupported ?? true,
                    NeftEnabled = ifscValidation.NeftSupported ?? true,
                    ImpsEnabled = ifscValidation.ImpsSupported ?? true,
                    UpiEnabled = ifscValidation.UpiSupported ?? true,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                };

                // Debug logging - log the entity before saving
                _logger.LogInformation($"Creating Payee entity:");
                _logger.LogInformation($"Entity PayeeName: '{payee.PayeeName}'");
                _logger.LogInformation($"Entity BeneficiaryName: '{payee.BeneficiaryName}'");
                _logger.LogInformation($"Entity UserId: '{payee.UserId}'");
                _logger.LogInformation($"Entity AccountNumber: '{payee.AccountNumber}'");

                _context.Payees.Add(payee);
                
                // Debug EF tracking before save
                var entry = _context.Entry(payee);
                _logger.LogInformation($"EF Entry State: {entry.State}");
                foreach (var property in entry.Properties)
                {
                    _logger.LogInformation($"Property {property.Metadata.Name}: Value='{property.CurrentValue}', Modified={property.IsModified}");
                }

                await _context.SaveChangesAsync();

                _logger.LogInformation($"Payee added successfully for user: {userId}, PayeeId: {payee.Id}");

                return new PayeeResponse
                {
                    Id = payee.Id,
                    PayeeName = payee.PayeeName,
                    AccountNumber = payee.AccountNumber,
                    IfscCode = payee.IfscCode,
                    BankName = payee.BankName,
                    BranchName = payee.BranchName,
                    AccountType = payee.AccountType,
                    City = payee.City,
                    State = payee.State,
                    BranchAddress = payee.BranchAddress,
                    ContactNumber = payee.ContactNumber,
                    MicrCode = payee.MicrCode,
                    BankCode = payee.BankCode,
                    RtgsEnabled = payee.RtgsEnabled,
                    NeftEnabled = payee.NeftEnabled,
                    ImpsEnabled = payee.ImpsEnabled,
                    UpiEnabled = payee.UpiEnabled,
                    CreatedAt = payee.CreatedAt,
                    UpdatedAt = payee.UpdatedAt
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error adding payee for user: {userId}");
                throw;
            }
        }

        public async Task<bool> DeletePayeeAsync(int payeeId, string userId)
        {
            try
            {
                var payee = await _context.Payees
                    .FirstOrDefaultAsync(p => p.Id == payeeId && p.UserId == userId);

                if (payee == null)
                    return false;

                _context.Payees.Remove(payee);
                await _context.SaveChangesAsync();

                _logger.LogInformation($"Payee deleted successfully: {payeeId} for user: {userId}");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error deleting payee {payeeId} for user: {userId}");
                throw;
            }
        }

        public async Task<bool> PayeeExistsAsync(string accountNumber, string ifscCode, string userId)
        {
            try
            {
                return await _context.Payees
                    .AnyAsync(p => p.UserId == userId && 
                                 p.AccountNumber == accountNumber && 
                                 p.IfscCode == ifscCode);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error checking payee existence for user: {userId}");
                throw;
            }
        }
    }
}