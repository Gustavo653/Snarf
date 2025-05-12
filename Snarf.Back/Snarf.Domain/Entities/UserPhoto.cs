using Snarf.Domain.Base;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Snarf.Domain.Entities
{
    public class UserPhoto : BaseEntity
    {
        public string Url { get; set; } = null!;
        public int Order { get; set; }
        public string UserId { get; set; } = null!;
        public User User { get; set; } = null!;
    }
}
