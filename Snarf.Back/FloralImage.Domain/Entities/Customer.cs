using FloralImage.Domain.Base;
using FloralImage.Domain.Enum;
using FloralImage.Domain.Location;

namespace FloralImage.Domain.Entities
{
    public class Customer : BaseEntity
    {
        public required int Number { get; set; }
        public required string Document { get; set; }
        public required string Name { get; set; }
        public required string CompanyName { get; set; }
        public required string Address { get; set; }
        public required string PostalCode { get; set; }
        public required City City { get; set; }
        public required State State { get; set; }
        public required string Email { get; set; }
        public required DateTime ContractStartDate { get; set; }
        public required DateTime ReferenceStartDate { get; set; }
        public required DateTime ReferenceEndDate { get; set; }
        public required InvoiceGenerationOption InvoiceGenerationOption { get; set; }
        public string? AdditionalInfo { get; set; }

        public required BillingStatus BillingStatus { get; set; }
        public required int CustomerInvoiceDate { get; set; }
        public required DateTime BillDueDate { get; set; }

        public virtual IList<CustomerXProduct> CustomerXProducts { get; set; }
        public virtual IList<Invoice> Invoices { get; set; }

        public void SetBillAndReferenceDates()
        {
            BillDueDate = BillDueDate.AddMonths(1);
            ReferenceStartDate = ReferenceStartDate.AddMonths(1);
            ReferenceEndDate = ReferenceEndDate.AddMonths(1);
        }
    }
}
