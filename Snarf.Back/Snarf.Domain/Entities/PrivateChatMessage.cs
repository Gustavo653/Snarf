using Snarf.Domain.Base;

namespace Snarf.Domain.Entities
{
    public class PrivateChatMessage : BaseEntity
    {
        public required User Sender { get; set; }
        public required User Receiver { get; set; }
        public required string Message { get; set; }
        public required bool IsRead { get; set; }
    }
}
