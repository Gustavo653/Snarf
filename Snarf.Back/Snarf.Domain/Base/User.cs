using Microsoft.AspNetCore.Identity;
using Snarf.Domain.Entities;
using Snarf.Domain.Enum;
using Snarf.Domain.Enum.UserDetails;

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

        public decimal? HeightInCm { get; set; }
        public bool ShowHeightInCm { get; set; }

        public decimal? WeightInKg { get; set; }
        public bool ShowWeightInKg { get; set; }

        public bool? IsCircumcised { get; set; }
        public bool ShowIsCircumcised { get; set; }

        public decimal? SizeInCm { get; set; }
        public bool ShowSizeInCm { get; set; }

        public BodyType? BodyType { get; set; }
        public bool ShowBodyType { get; set; }



        public SexualSpectrum? Spectrum { get; set; }
        public bool ShowSpectrum { get; set; }

        public SexualAttitude? Attitude { get; set; }
        public bool ShowAttitude { get; set; }

        public List<ExpressionStyle> Expressions { get; set; } = [];
        public bool ShowExpressions { get; set; }


        public HostingStatus HostingStatus { get; set; }
        public bool ShowHostingStatus { get; set; }

        public PublicPlace PublicPlace { get; set; }
        public bool ShowPublicPlace { get; set; }

        public List<ExpressionStyle> LookingFor { get; set; } = [];
        public bool ShowLookingFor { get; set; }

        public List<Kink> Kinks { get; set; } = [];
        public bool ShowKinks { get; set; }

        public List<Fetish> Fetishes { get; set; } = [];
        public bool ShowFetishes { get; set; }

        public List<ActionLike> ActionsLiked { get; set; } = [];
        public bool ShowActionsLiked { get; set; }

        public List<Interaction> Interactions { get; set; } = [];
        public bool ShowInteractions { get; set; }



        public Practice? Practice { get; set; }
        public bool ShowPractice { get; set; }

        public HivStatus? HivStatus { get; set; }
        public bool ShowHivStatus { get; set; }

        public DateTime? HivTestedDate { get; set; }
        public bool ShowHivTestedDate { get; set; }

        public DateTime? StiTestedDate { get; set; }
        public bool ShowStiTestedDate { get; set; }

        public List<ImmunizationStatus> Immunizations { get; set; } = [];
        public bool ShowImmunizations { get; set; }

        public List<DrugAbuse> DrugComfort { get; set; } = [];
        public bool ShowDrugComfort { get; set; }

        public List<Carrying> CarryingItems { get; set; } = [];
        public bool ShowCarryingItems { get; set; }



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