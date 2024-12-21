using Snarf.Domain.Base;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using Snarf.Domain.Entities;

namespace Snarf.Persistence
{
    public class SnarfContext(DbContextOptions<SnarfContext> options) : IdentityDbContext<User>(options)
    {
        public DbSet<ChatMessage> ChatMessages { get; set; }
        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);
        }
    }
}