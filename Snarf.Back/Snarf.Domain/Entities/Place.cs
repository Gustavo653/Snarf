using Snarf.Domain.Base;
using Snarf.Domain.Enum;
using System.ComponentModel.DataAnnotations.Schema;

namespace Snarf.Domain.Entities
{
    public class Place : BaseEntity
    {
        public required string Title { get; set; }
        public required string Description { get; set; }
        public required double Latitude { get; set; }
        public required double Longitude { get; set; }
        public required string OwnerId { get; set; }
        public virtual User? Owner { get; set; }
        public required string CoverImageUrl { get; set; }
    }
}
