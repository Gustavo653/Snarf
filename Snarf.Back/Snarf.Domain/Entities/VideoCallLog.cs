using Snarf.Domain.Base;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Snarf.Domain.Entities
{
    public class VideoCallLog : BaseEntity
    {
        public required string RoomId { get; set; }
        public virtual required User Caller { get; set; }
        public virtual required User Callee { get; set; }
        public required DateTime StartTime { get; set; }
        public DateTime? EndTime { get; set; }
        public int DurationMinutes { get; set; }
    }
}
