using FloralImage.Domain.Base;

namespace FloralImage.Domain.Entities
{
    public class InvoiceItem : BaseEntity
    {
        public required Invoice Invoice { get; set; }
        public required Product Product { get; set; }
        public required int Quantity { get; set; }
        public required decimal Price { get; set; }
    }
}
