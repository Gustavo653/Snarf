using Snarf.Domain.Enum;
using System.ComponentModel.DataAnnotations;

namespace Snarf.DTO
{
    public class PartyDTO
    {
        [Required]
        public required string Title { get; set; }
        [Required]
        public required string Description { get; set; }
        [Required]
        public required DateTime StartDate { get; set; }
        [Required]
        public required int Duration { get; set; }
        [Required]
        public required PartyType Type { get; set; }
        [Required]
        public required string Location { get; set; }
        [Required]
        public required string Instructions { get; set; }
        [Required]
        public required string CoverImage { get; set; }
        [Required]
        public required double LastLatitude { get; set; }
        [Required]
        public required double LastLongitude { get; set; }
        public string? UserId { get; set; }
    }
}
