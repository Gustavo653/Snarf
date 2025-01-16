using Snarf.Domain.Base;

namespace Snarf.Domain.Entities
{
    public class FavoriteChat : BaseEntity
    {
        public required User User { get; set; }
        public required User ChatUser { get; set; }
    }
}
