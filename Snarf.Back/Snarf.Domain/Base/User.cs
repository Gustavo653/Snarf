using Microsoft.AspNetCore.Identity;
using Snarf.Domain.Entities;
using Snarf.Domain.Enum;

namespace Snarf.Domain.Base
{
    public class User : IdentityUser
    {
        public required string Name { get; set; }
        public required string ImageUrl { get; set; }
        public DateTime? LastActivity { get; set; }
        public double? LastLatitude { get; set; }
        public double? LastLongitude { get; set; }
        public string? FcmToken { get; set; }
        public required RoleName Role { get; set; }
        public int ExtraVideoCallMinutes { get; set; }

        public virtual IList<BlockedUser> BlockedUsers { get; set; } = [];
        public virtual IList<BlockedUser> BlockedBy { get; set; } = [];

        public virtual IList<FavoriteChat> FavoriteChats { get; set; } = [];
        public virtual IList<FavoriteChat> FavoritedBy { get; set; } = [];
    }
}