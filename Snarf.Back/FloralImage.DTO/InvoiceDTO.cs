using System.ComponentModel.DataAnnotations;

namespace FloralImage.DTO
{
    public class InvoiceDTO
    {
        [Required]
        public required DateTime IssueDate { get; set; }
        [Required]
        public required Guid CustomerId { get; set; }
        [Required]
        public required DateTime ReferenceStartDate { get; set; }
        public required DateTime? BillDueDate { get; set; }
        [Required]
        public required DateTime ReferenceEndDate { get; set; }
        [Required]
        public required virtual IList<InvoiceItemDTO> InvoiceItems { get; set; }
    }

    public class InvoiceItemDTO
    {
        [Required]
        public required Guid ItemId { get; set; }
        [Required]
        public required Guid ProductId { get; set; }
        [Required]
        public required int Quantity { get; set; }
        [Required]
        public required decimal Price { get; set; }
    }
}