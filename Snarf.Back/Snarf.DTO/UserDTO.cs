using Snarf.Domain.Enum;
using Snarf.Domain.Enum.UserDetails;
using System;
using System.Collections.Generic;
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

        // STATS
        public int? Age { get; set; }
        public bool? ShowAge { get; set; }

        public decimal? Height { get; set; }
        public bool? ShowHeightInCm { get; set; }

        public decimal? Weight { get; set; }
        public bool? ShowWeightInKg { get; set; }

        public BodyType? BodyType { get; set; }
        public bool? ShowBodyType { get; set; }

        public bool? IsCircumcised { get; set; }
        public bool? ShowIsCircumcised { get; set; }

        public decimal? CircumferenceCm { get; set; }
        public bool? ShowSizeInCm { get; set; }

        // SEXUALITY
        public SexualSpectrum? Spectrum { get; set; }
        public bool? ShowSpectrum { get; set; }

        public SexualAttitude? Attitude { get; set; }
        public bool? ShowAttitude { get; set; }

        public List<ExpressionStyle>? Expressions { get; set; }
        public bool? ShowExpressions { get; set; }

        // SCENE
        public HostingStatus? HostingStatus { get; set; }
        public bool? ShowHostingStatus { get; set; }

        public PublicPlace? PublicPlace { get; set; }
        public bool? ShowPublicPlace { get; set; }

        public List<ExpressionStyle>? LookingFor { get; set; }
        public bool? ShowLookingFor { get; set; }

        public List<Kink>? Kinks { get; set; }
        public bool? ShowKinks { get; set; }

        public List<Fetish>? Fetishes { get; set; }
        public bool? ShowFetishes { get; set; }

        public List<Actions>? Actions { get; set; }
        public bool? ShowActions { get; set; }

        public List<Interaction>? Interactions { get; set; }
        public bool? ShowInteractions { get; set; }

        // HEALTH
        public Practice? Practice { get; set; }
        public bool? ShowPractice { get; set; }

        public HivStatus? HivStatus { get; set; }
        public bool? ShowHivStatus { get; set; }

        public DateTime? HivTestedDate { get; set; }
        public bool? ShowHivTestedDate { get; set; }

        public DateTime? StiTestedDate { get; set; }
        public bool? ShowStiTestedDate { get; set; }

        public List<ImmunizationStatus>? Immunizations { get; set; }
        public bool? ShowImmunizations { get; set; }

        public List<DrugAbuse>? DrugAbuse { get; set; }
        public bool? ShowDrugAbuse { get; set; }

        public List<Carrying>? Carrying { get; set; }
        public bool? ShowCarrying { get; set; }
    }
}