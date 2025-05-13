using Microsoft.AspNetCore.Identity;
using Snarf.Domain.Entities;
using Snarf.Domain.Enum;

namespace Snarf.Domain.Base
{
    public class User : IdentityUser
    {
        public required string Name { get; set; }
        public DateTime? LastActivity { get; set; }
        public double? LastLatitude { get; set; }
        public double? LastLongitude { get; set; }
        public string? FcmToken { get; set; }
        public required RoleName Role { get; set; }

        public string? Description { get; set; }

        public double? BirthLatitude { get; set; }
        public double? BirthLongitude { get; set; }

        public LocationAvailability? LocationAvailability { get; set; }

        public int? Age { get; set; }
        public bool ShowAge { get; set; }

        public decimal? Height { get; set; }
        public bool ShowHeight { get; set; }

        public decimal? Weight { get; set; }
        public bool ShowWeight { get; set; }

        public bool? IsCircumcised { get; set; }
        public bool ShowIsCircumcised { get; set; }

        public decimal? CircumferenceCm { get; set; }
        public bool ShowCircumferenceCm { get; set; }

        public BodyType? BodyType { get; set; }
        public bool ShowBodyType { get; set; }
        public SexualSpectrum? Spectrum { get; set; }
        public bool ShowSpectrum { get; set; }

        public SexualAttitude? Attitude { get; set; }
        public bool ShowAttitude { get; set; }

        public List<ExpressionStyle> Expressions { get; set; } = [];
        public bool ShowExpressions { get; set; }

        public string GetFirstPhoto => Photos.FirstOrDefault(x => x.Order == 1)?.Url ?? string.Empty;
        public IList<UserPhoto> Photos { get; set; } = [];

        public virtual IList<BlockedUser> BlockedUsers { get; set; } = [];
        public virtual IList<BlockedUser> BlockedBy { get; set; } = [];
        public virtual IList<FavoriteChat> FavoriteChats { get; set; } = [];
        public virtual IList<FavoriteChat> FavoritedBy { get; set; } = [];

        public virtual IList<Party> Invitations { get; set; } = [];
        public virtual IList<Party> ConfirmedParties { get; set; } = [];
        public virtual IList<Party> OwnedParties { get; set; } = [];
        public virtual IList<VideoCallPurchase> VideoCallPurchases { get; set; } = [];
    }
}