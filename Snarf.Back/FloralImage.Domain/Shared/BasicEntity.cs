using FloralImage.Domain.Base;

namespace FloralImage.Domain.Shared
{
    public abstract class BasicEntity : BaseEntity
    {
        public required string Name { get; set; }
    }
}
