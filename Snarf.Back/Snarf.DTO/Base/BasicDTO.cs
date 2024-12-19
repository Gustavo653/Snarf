using System.ComponentModel.DataAnnotations;

namespace Snarf.DTO.Base
{
    public class BasicDTO
    {
        [Required]
        public required string Name { get; set; }
    }
}