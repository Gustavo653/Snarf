using Snarf.Domain.Base;

namespace Snarf.Domain.Entities
{
    public class UserPhoto : BaseEntity
    {
        public string Url { get; set; } = null!;
        public int Order { get; set; }
        public string UserId { get; set; } = null!;
        public User User { get; set; } = null!;
    }
}
