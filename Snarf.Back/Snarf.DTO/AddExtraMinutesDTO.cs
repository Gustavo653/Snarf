using System.ComponentModel.DataAnnotations;

namespace Snarf.DTO
{
    public class AddExtraMinutesDTO
    {
        public Guid UserId { get; set; }
        [Required]
        public required string SubscriptionId { get; set; }
        [Required]
        public required string Token { get; set; }
        [Required]
        public required int Minutes { get; set; }
    }
}