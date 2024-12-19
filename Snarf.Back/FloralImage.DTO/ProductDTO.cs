using FloralImage.DTO.Base;
using System.ComponentModel.DataAnnotations;

namespace FloralImage.DTO
{
    public class ProductDTO : BasicDTO
    {
        [Required]
        public required decimal Price { get; set; }
    }
}
