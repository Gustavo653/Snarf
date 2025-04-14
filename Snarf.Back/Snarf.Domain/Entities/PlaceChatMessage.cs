using Snarf.Domain.Base;

namespace Snarf.Domain.Entities
{
    public class PlaceChatMessage : BaseEntity
    {
        public string SenderId { get; set; }
        public virtual User? Sender { get; set; }
        public Guid PlaceId { get; set; }
        public virtual Place? Place { get; set; }
        public required string Message { get; set; }
    }
}
