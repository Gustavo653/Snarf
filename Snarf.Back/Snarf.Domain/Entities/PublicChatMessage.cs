using Snarf.Domain.Base;

namespace Snarf.Domain.Entities
{
    public class PublicChatMessage : BaseEntity
    {
        public required string SenderId { get; set; }
        public virtual User? Sender { get; set; }
        public required string Message { get; set; }
    }
}
