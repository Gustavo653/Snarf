using Snarf.Domain.Enum;
using Microsoft.AspNetCore.Identity;

namespace Snarf.Domain.Base
{
    public class User : IdentityUser
    {
        public required string Name { get; set; }
        public required string ImageUrl { get; set; }
        public DateTime? LastActivity { get; set; }
        public double? LastLatitude { get; set; }
        public double? LastLongitude { get; set; }
        public required RoleName Role { get; set; }
    }
}