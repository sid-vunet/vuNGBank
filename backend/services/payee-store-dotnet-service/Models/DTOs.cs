using System.ComponentModel.DataAnnotations;

namespace PayeeService.Models.DTOs
{
    public class AddPayeeRequest
    {
        [Required]
        [StringLength(100, MinimumLength = 2)]
        public string BeneficiaryName { get; set; } = string.Empty;

        [Required]
        [StringLength(50, MinimumLength = 8)]
        public string AccountNumber { get; set; } = string.Empty;

        [Required]
        [StringLength(11, MinimumLength = 11)]
        [RegularExpression(@"^[A-Z]{4}0[A-Z0-9]{6}$", ErrorMessage = "Invalid IFSC code format")]
        public string IfscCode { get; set; } = string.Empty;

        [Required]
        [StringLength(20)]
        public string AccountType { get; set; } = "Savings";
    }

    public class PayeeResponse
    {
        public int Id { get; set; }
        public string BeneficiaryName { get; set; } = string.Empty;
        public string AccountNumber { get; set; } = string.Empty;
        public string IfscCode { get; set; } = string.Empty;
        public string BankName { get; set; } = string.Empty;
        public string BranchName { get; set; } = string.Empty;
        public string AccountType { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
    }

    public class CheckPayeeExistsRequest
    {
        [Required]
        public string AccountNumber { get; set; } = string.Empty;

        [Required]
        public string IfscCode { get; set; } = string.Empty;
    }

    public class PayeeExistsResponse
    {
        public bool Exists { get; set; }
    }

    public class IfscValidationRequest
    {
        [Required]
        [StringLength(11, MinimumLength = 11)]
        public string IfscCode { get; set; } = string.Empty;
    }

    public class IfscValidationResponse
    {
        public bool IsValid { get; set; }
        public string? BankName { get; set; }
        public string? BranchName { get; set; }
        public string? City { get; set; }
        public string? State { get; set; }
        public string? ErrorMessage { get; set; }
    }

    public class ApiResponse<T>
    {
        public bool Success { get; set; }
        public string Message { get; set; } = string.Empty;
        public T? Data { get; set; }
        public List<string>? Errors { get; set; }
    }
}