using Snarf.Domain.Base;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

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
