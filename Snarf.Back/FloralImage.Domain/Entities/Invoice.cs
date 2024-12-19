using FloralImage.Domain.Base;
using FloralImage.Domain.Enum;

namespace FloralImage.Domain.Entities
{
    public class Invoice : BaseEntity
    {
        public int? Number { get; set; }
        public required InvoiceStatus InvoiceStatus { get; set; }
        public required DateTime IssueDate { get; set; }
        public required Customer Customer { get; set; }
        public required DateTime ReferenceStartDate { get; set; }
        public required DateTime ReferenceEndDate { get; set; }
        public DateTime? BillDueDate { get; set; }
        public required IList<InvoiceItem> InvoiceItems { get; set; }
    }
}
