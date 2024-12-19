using System.ComponentModel.DataAnnotations;

namespace FloralImage.DTO.Base
{
    public class BasicDTO
    {
        [Required]
        public required string Name { get; set; }
    }
}