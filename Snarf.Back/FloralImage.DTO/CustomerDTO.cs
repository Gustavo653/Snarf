using FloralImage.Domain.Enum;
using System.ComponentModel.DataAnnotations;

namespace FloralImage.DTO
{
    public class CustomerDTO
    {
        [Required]
        public required string Document { get; set; }
        [Required]
        public required int Number { get; set; }
        [Required]
        public required string Name { get; set; }
        [Required]
        public required string CompanyName { get; set; }
        [Required]
        public required string Address { get; set; }
        [Required]
        public required string PostalCode { get; set; }
        [Required]
        public required Guid CityId { get; set; }
        [Required]
        public required Guid StateId { get; set; }
        [Required]
        public required DateTime ContractStartDate { get; set; }
        [Required]
        public required string Email { get; set; }
        public string? AdditionalInfo { get; set; }
        [Required]
        public required InvoiceGenerationOption InvoiceGenerationOption { get; set; }

        [Required]
        public required BillingStatus BillingStatus { get; set; }
        [Required]
        public required int CustomerInvoiceDate { get; set; }
        [Required]
        public required DateTime BillDueDate { get; set; }
        [Required]
        public required DateTime ReferenceStartDate { get; set; }
        [Required]
        public required DateTime ReferenceEndDate { get; set; }

        public IList<ProductCustomerDTO>? Products { get; set; }
    }

    public class ProductCustomerDTO
    {
        [Required]
        public required Guid Id { get; set; }
        [Required]
        public required int Quantity { get; set; }
        [Required]
        public required decimal Price { get; set; }
    }
}
