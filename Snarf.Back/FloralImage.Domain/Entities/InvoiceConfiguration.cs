using FloralImage.Domain.Base;
using FloralImage.Domain.Location;

namespace FloralImage.Domain.Entities
{
    public class InvoiceConfiguration : BaseEntity
    {

        public required int NextNumber { get; set; }
        public required string Document { get; set; }
        public required string CompanyName { get; set; }
        public required string MunicipalRegistration { get; set; }
        public required string Address { get; set; }
        public required string PostalCode { get; set; }
        public required City City { get; set; }
        public required State State { get; set; }
        public required string Email { get; set; }
    }
}
