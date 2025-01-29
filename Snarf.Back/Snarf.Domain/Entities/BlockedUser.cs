using Snarf.Domain.Base;

namespace Snarf.Domain.Entities
{
    public class BlockedUser : BaseEntity
    {
        public required User Blocker { get; set; }
        public required User Blocked { get; set; }
    }
}
