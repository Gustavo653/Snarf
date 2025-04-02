using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Snarf.DTO
{
    public class GetAllParticipantsResponseDTO
    {
        public Guid Id { get; set; }
        public string EventType { get; set; }
        public string Title { get; set; }
        public string ImageUrl { get; set; }
        public string UserRole { get; set; }

    }
}
