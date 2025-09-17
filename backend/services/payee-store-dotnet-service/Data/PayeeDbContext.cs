using Microsoft.EntityFrameworkCore;
using PayeeService.Models;

namespace PayeeService.Data
{
    public class PayeeDbContext : DbContext
    {
        public PayeeDbContext(DbContextOptions<PayeeDbContext> options) : base(options)
        {
        }

        public DbSet<Payee> Payees { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // Configure Payee entity
            modelBuilder.Entity<Payee>(entity =>
            {
                entity.ToTable("payees");
                
                entity.HasIndex(e => new { e.UserId, e.AccountNumber, e.IfscCode })
                      .IsUnique()
                      .HasDatabaseName("ix_payees_user_account_ifsc");

                entity.HasIndex(e => e.UserId)
                      .HasDatabaseName("ix_payees_user_id");

                entity.Property(e => e.CreatedAt)
                      .HasDefaultValueSql("CURRENT_TIMESTAMP");

                // Seed some sample data with real IFSC codes
                entity.HasData(
                    new Payee
                    {
                        Id = 1,
                        UserId = "john.doe@example.com",
                        BeneficiaryName = "Rajesh Kumar",
                        AccountNumber = "123456789012",
                        IfscCode = "SBIN0000001",
                        BankName = "State Bank of India",
                        BranchName = "New Delhi Main Branch",
                        AccountType = "Savings",
                        CreatedAt = DateTime.UtcNow.AddDays(-30)
                    },
                    new Payee
                    {
                        Id = 2,
                        UserId = "john.doe@example.com",
                        BeneficiaryName = "Priya Sharma",
                        AccountNumber = "987654321098",
                        IfscCode = "HDFC0000001",
                        BankName = "HDFC Bank",
                        BranchName = "Mumbai Fort",
                        AccountType = "Savings",
                        CreatedAt = DateTime.UtcNow.AddDays(-20)
                    },
                    new Payee
                    {
                        Id = 3,
                        UserId = "john.doe@example.com",
                        BeneficiaryName = "Amit Patel",
                        AccountNumber = "555666777888",
                        IfscCode = "ICIC0000001",
                        BankName = "ICICI Bank",
                        BranchName = "Ahmedabad Corporate",
                        AccountType = "Current",
                        CreatedAt = DateTime.UtcNow.AddDays(-15)
                    },
                    new Payee
                    {
                        Id = 4,
                        UserId = "john.doe@example.com",
                        BeneficiaryName = "Sunita Reddy",
                        AccountNumber = "111222333444",
                        IfscCode = "AXIS0000001",
                        BankName = "Axis Bank",
                        BranchName = "Hyderabad Banjara Hills",
                        AccountType = "Savings",
                        CreatedAt = DateTime.UtcNow.AddDays(-10)
                    },
                    new Payee
                    {
                        Id = 5,
                        UserId = "john.doe@example.com",
                        BeneficiaryName = "Vikram Singh",
                        AccountNumber = "999888777666",
                        IfscCode = "KKBK0000001",
                        BankName = "Kotak Mahindra Bank",
                        BranchName = "Bangalore Whitefield",
                        AccountType = "Current",
                        CreatedAt = DateTime.UtcNow.AddDays(-5)
                    }
                );
            });
        }
    }
}