using Snarf.Domain.Base;

namespace Snarf.Domain.Entities
{
    public class PlaceVisitLog : BaseEntity
    {
        public required string UserId { get; set; }
        public required Guid PlaceId { get; set; }
        public DateTime EntryTime { get; set; }
        public DateTime? ExitTime { get; set; }

        public double? TotalDurationInMinutes { get; set; }

        public virtual User? User { get; set; }
        public virtual Place? Place { get; set; }
    }
}
