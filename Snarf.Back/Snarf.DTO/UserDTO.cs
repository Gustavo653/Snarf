using Snarf.Domain.Enum.UserDetails;
using System.ComponentModel.DataAnnotations;

namespace Snarf.DTO
{
    public class UserDTO
    {
        [Required]
        [EmailAddress]
        public required string Email { get; set; }
        [Required]
        public required string Name { get; set; }
        public string? Password { get; set; }

        public List<string>? Images { get; set; }
        public string? Description { get; set; }
        public double? BirthLatitude { get; set; }
        public double? BirthLongitude { get; set; }

        public LocationAvailability? LocationAvailability { get; set; }

        public int? Age { get; set; }
        public decimal? Height { get; set; }
        public decimal? Weight { get; set; }

        public bool? IsCircumcised { get; set; }
        public decimal? CircumferenceCm { get; set; }

        public BodyType? BodyType { get; set; }
    }
}