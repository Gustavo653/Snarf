using Snarf.Domain.Base;

namespace Snarf.Domain.Entities
{
    public class VideoCallPurchase : BaseEntity
    {
        public string UserId { get; set; } = null!;
        public User User { get; set; } = null!;

        public int Minutes { get; set; }

        public DateTime PurchaseDate { get; set; }

        public string? SubscriptionId { get; set; }
        public string? Token { get; set; }
    }
}
