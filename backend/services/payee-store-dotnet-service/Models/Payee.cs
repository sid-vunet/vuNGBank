using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace PayeeService.Models
{
    [Table("payees")]
    public class Payee
    {
        [Key]
        [Column("id")]
        public int Id { get; set; }

        [Required]
        [StringLength(50)]
        [Column("user_id")]
        public string UserId { get; set; } = string.Empty;

        [Required]
        [StringLength(100)]
        [Column("payee_name")]
        public string PayeeName { get; set; } = string.Empty;

        [Required]
        [StringLength(100)]
        [Column("beneficiary_name")]
        public string BeneficiaryName { get; set; } = string.Empty;

        [Required]
        [StringLength(50)]
        [Column("account_number")]
        public string AccountNumber { get; set; } = string.Empty;

        [Required]
        [StringLength(11)]
        [Column("ifsc_code")]
        public string IfscCode { get; set; } = string.Empty;

        [Required]
        [StringLength(100)]
        [Column("bank_name")]
        public string BankName { get; set; } = string.Empty;

        [Required]
        [StringLength(100)]
        [Column("branch_name")]
        public string BranchName { get; set; } = string.Empty;

        [Required]
        [StringLength(20)]
        [Column("account_type")]
        public string AccountType { get; set; } = "Savings";

        // Enhanced fields from Razorpay IFSC API
        [StringLength(50)]
        [Column("city")]
        public string? City { get; set; }

        [StringLength(50)]
        [Column("state")]
        public string? State { get; set; }

        [Column("branch_address")]
        public string? BranchAddress { get; set; }

        [StringLength(20)]
        [Column("contact_number")]
        public string? ContactNumber { get; set; }

        [StringLength(20)]
        [Column("micr_code")]
        public string? MicrCode { get; set; }

        [StringLength(10)]
        [Column("bank_code")]
        public string? BankCode { get; set; }

        // Payment method support flags
        [Column("rtgs_enabled")]
        public bool RtgsEnabled { get; set; } = true;

        [Column("neft_enabled")]
        public bool NeftEnabled { get; set; } = true;

        [Column("imps_enabled")]
        public bool ImpsEnabled { get; set; } = true;

        [Column("upi_enabled")]
        public bool UpiEnabled { get; set; } = true;

        [Column("created_at")]
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        [Column("updated_at")]
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }
}