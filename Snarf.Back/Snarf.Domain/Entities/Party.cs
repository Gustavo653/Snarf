using Snarf.Domain.Base;
using Snarf.Domain.Enum;
using System.ComponentModel.DataAnnotations.Schema;

namespace Snarf.Domain.Entities
{
    public class Party : BaseEntity
    {
        public required string Title { get; set; }
        public string? Description { get; set; }
        public PartyType Type { get; set; }
        public DateTime StartDate { get; set; }
        public int Duration { get; set; }
        public required string Location { get; set; }
        public required string Instructions { get; set; }
        public string? CoverImageUrl { get; set; }
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }

        public required string OwnerId { get; set; }
        public required User Owner { get; set; }

        public virtual IList<User> InvitedUsers { get; set; } = [];
        public virtual IList<User> ConfirmedUsers { get; set; } = [];

        public string? InvitedByHostJson { get; set; }
        [NotMapped]
        public Dictionary<string, bool> InvitedByHostMap
        {
            get
            {
                if (string.IsNullOrEmpty(InvitedByHostJson))
                    return new Dictionary<string, bool>();
                return System.Text.Json.JsonSerializer.Deserialize<Dictionary<string, bool>>(InvitedByHostJson)
                       ?? new Dictionary<string, bool>();
            }
            set
            {
                InvitedByHostJson = System.Text.Json.JsonSerializer.Serialize(value);
            }
        }
    }
}
