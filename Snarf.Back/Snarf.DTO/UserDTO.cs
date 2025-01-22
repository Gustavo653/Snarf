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
        [Required]
        public required string Image { get; set; }
        public string? Password { get; set; }
    }
}