using FloralImage.Domain.Base;

namespace FloralImage.Domain.Entities
{
    public class Product : BaseEntity
    {
        public required string Name { get; set; }
        public required decimal Price { get; set; }
        public virtual IList<CustomerXProduct>? CustomerXProducts { get; set; }
    }
}
