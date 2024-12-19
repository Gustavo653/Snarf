using Snarf.Domain.Base;

namespace Snarf.Domain.Shared
{
    public abstract class BasicEntity : BaseEntity
    {
        public required string Name { get; set; }
    }
}
