using Snarf.DTO.Base;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Security.AccessControl;
using System.Text;
using System.Threading.Tasks;

namespace Snarf.DTO
{
    public class PlaceDTO
    {
        [Required]
        public required string Title { get; set; }
        [Required]
        public required string Description { get; set; }
        [Required]
        public required double Latitude { get; set; }
        [Required]
        public required double Longitude { get; set; }
        [Required]
        public required string CoverImage { get; set; }
        [Required]
        public required PlaceType Type { get; set; }
        public string? UserId { get; set; }
    }
}
