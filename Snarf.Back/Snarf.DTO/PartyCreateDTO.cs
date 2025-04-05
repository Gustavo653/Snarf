using Snarf.Domain.Enum;
using System.ComponentModel.DataAnnotations;

namespace Snarf.DTO
{
    public class PartyCreateDTO
    {
        [Required]
        public string Title { get; set; }
        [Required]
        public string Description { get; set; }
        [Required]
        public DateTime StartDate { get; set; }
        [Required]
        public int Duration { get; set; }
        [Required]
        public PartyType Type { get; set; }
        public string Location { get; set; }
        public string Instructions { get; set; }
        public string CoverImage { get; set; }
        public double? LastLatitude { get; set; }
        public double? LastLongitude { get; set; }
        public string? UserId { get; set; }
    }
}
