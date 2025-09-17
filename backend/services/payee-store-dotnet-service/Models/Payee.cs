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

        [Column("created_at")]
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}