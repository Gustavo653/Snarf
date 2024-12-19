using System.ComponentModel.DataAnnotations;

namespace FloralImage.DTO
{
    public class UserDTO
    {
        [Required]
        [EmailAddress]
        public required string Email { get; set; }
        [Required]
        public required string Name { get; set; }
        public string? Password { get; set; }
    }
}