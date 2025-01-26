using Snarf.Domain.Base;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Snarf.Domain.Entities
{
    public class BlockedUser : BaseEntity
    {
        public required User Blocker { get; set; }
        public required User Blocked { get; set; }
    }
}
