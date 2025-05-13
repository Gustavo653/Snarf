using Snarf.Domain.Enum;
using System.ComponentModel.DataAnnotations;

namespace Snarf.DTO
{
    public class PlaceDTO
    {
        [Required]
        public required string Title { get; set; }
        [Required]
        public required string Description { get; set; }
        [Required]
        public required double Latitude { get; set; }
        [Required]
        public required double Longitude { get; set; }
        [Required]
        public required string CoverImage { get; set; }
        [Required]
        public required PlaceType Type { get; set; }
        public string? UserId { get; set; }
    }
}
