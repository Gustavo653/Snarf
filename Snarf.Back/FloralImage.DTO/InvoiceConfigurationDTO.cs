using System.ComponentModel.DataAnnotations;

namespace FloralImage.DTO
{
    public class InvoiceConfigurationDTO
    {
        [Required]
        public required int NextNumber { get; set; }
        [Required]
        public required string Document { get; set; }
        [Required]
        public required string CompanyName { get; set; }
        [Required]
        public required string MunicipalRegistration { get; set; }
        [Required]
        public required string Address { get; set; }
        [Required]
        public required string PostalCode { get; set; }
        [Required]
        public required Guid CityId { get; set; }
        [Required]
        public required Guid StateId { get; set; }
        [Required]
        public required string Email { get; set; }
    }
}