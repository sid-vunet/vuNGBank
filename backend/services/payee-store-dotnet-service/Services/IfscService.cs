using PayeeService.Models.DTOs;
using Newtonsoft.Json;
using System.Text.Json.Serialization;

namespace PayeeService.Services
{
    public interface IIfscService
    {
        Task<IfscValidationResponse> ValidateIfscAsync(string ifscCode);
    }

    public class IfscService : IIfscService
    {
        private readonly HttpClient _httpClient;
        private readonly ILogger<IfscService> _logger;

        public IfscService(HttpClient httpClient, ILogger<IfscService> logger)
        {
            _httpClient = httpClient;
            _logger = logger;
        }

        public async Task<IfscValidationResponse> ValidateIfscAsync(string ifscCode)
        {
            try
            {
                var url = $"https://ifsc.razorpay.com/{ifscCode}";
                _logger.LogInformation($"Validating IFSC code: {ifscCode}");

                var response = await _httpClient.GetAsync(url);
                
                if (response.IsSuccessStatusCode)
                {
                    var content = await response.Content.ReadAsStringAsync();
                    var bankDetails = JsonConvert.DeserializeObject<RazorpayIfscResponse>(content);

                    if (bankDetails != null)
                    {
                        return new IfscValidationResponse
                        {
                            IsValid = true,
                            BankName = bankDetails.Bank ?? "Unknown Bank",
                            BranchName = bankDetails.Branch ?? "Unknown Branch",
                            City = bankDetails.City ?? "Unknown City",
                            State = bankDetails.State
                        };
                    }
                }

                _logger.LogWarning($"IFSC validation failed for code: {ifscCode}");
                return new IfscValidationResponse
                {
                    IsValid = false,
                    ErrorMessage = "Invalid IFSC code or bank details not found"
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error validating IFSC code: {ifscCode}");
                return new IfscValidationResponse
                {
                    IsValid = false,
                    ErrorMessage = "Unable to validate IFSC code at this time"
                };
            }
        }
    }

    // Response model for Razorpay IFSC API
    public class RazorpayIfscResponse
    {
        [JsonPropertyName("BANK")]
        public string? Bank { get; set; }

        [JsonPropertyName("BRANCH")]
        public string? Branch { get; set; }

        [JsonPropertyName("CITY")]
        public string? City { get; set; }

        [JsonPropertyName("STATE")]
        public string? State { get; set; }

        [JsonPropertyName("ADDRESS")]
        public string? Address { get; set; }

        [JsonPropertyName("CONTACT")]
        public string? Contact { get; set; }

        [JsonPropertyName("UPI")]
        public bool? Upi { get; set; }

        [JsonPropertyName("RTGS")]
        public bool? Rtgs { get; set; }

        [JsonPropertyName("NEFT")]
        public bool? Neft { get; set; }

        [JsonPropertyName("IMPS")]
        public bool? Imps { get; set; }
    }
}