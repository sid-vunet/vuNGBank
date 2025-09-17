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
                    .OrderBy(p => p.BeneficiaryName)
                    .ToListAsync();

                return payees.Select(p => new PayeeResponse
                {
                    Id = p.Id,
                    BeneficiaryName = p.BeneficiaryName,
                    AccountNumber = p.AccountNumber,
                    IfscCode = p.IfscCode,
                    BankName = p.BankName,
                    BranchName = p.BranchName,
                    AccountType = p.AccountType,
                    CreatedAt = p.CreatedAt
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
                    BeneficiaryName = payee.BeneficiaryName,
                    AccountNumber = payee.AccountNumber,
                    IfscCode = payee.IfscCode,
                    BankName = payee.BankName,
                    BranchName = payee.BranchName,
                    AccountType = payee.AccountType,
                    CreatedAt = payee.CreatedAt
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
                // Check if payee already exists
                var existingPayee = await _context.Payees
                    .FirstOrDefaultAsync(p => p.UserId == userId && 
                                            p.AccountNumber == request.AccountNumber && 
                                            p.IfscCode == request.IfscCode);

                if (existingPayee != null)
                {
                    throw new InvalidOperationException("Payee with this account number and IFSC code already exists");
                }

                // Validate IFSC code
                var ifscValidation = await _ifscService.ValidateIfscAsync(request.IfscCode);
                if (!ifscValidation.IsValid)
                {
                    throw new ArgumentException($"Invalid IFSC code: {ifscValidation.ErrorMessage}");
                }

                // Create new payee
                var payee = new Payee
                {
                    UserId = userId,
                    BeneficiaryName = request.BeneficiaryName,
                    AccountNumber = request.AccountNumber,
                    IfscCode = request.IfscCode.ToUpper(),
                    BankName = ifscValidation.BankName!,
                    BranchName = ifscValidation.BranchName!,
                    AccountType = request.AccountType,
                    CreatedAt = DateTime.UtcNow
                };

                _context.Payees.Add(payee);
                await _context.SaveChangesAsync();

                _logger.LogInformation($"Payee added successfully for user: {userId}, PayeeId: {payee.Id}");

                return new PayeeResponse
                {
                    Id = payee.Id,
                    BeneficiaryName = payee.BeneficiaryName,
                    AccountNumber = payee.AccountNumber,
                    IfscCode = payee.IfscCode,
                    BankName = payee.BankName,
                    BranchName = payee.BranchName,
                    AccountType = payee.AccountType,
                    CreatedAt = payee.CreatedAt
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