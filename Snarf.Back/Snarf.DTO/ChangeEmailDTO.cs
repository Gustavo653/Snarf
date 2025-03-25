using System.ComponentModel.DataAnnotations;

namespace Snarf.DTO
{
    public class ChangeEmailDTO
    {
        [Required]
        public required string NewEmail { get; set; }
        [Required]
        public required string CurrentPassword { get; set; }
    }
}