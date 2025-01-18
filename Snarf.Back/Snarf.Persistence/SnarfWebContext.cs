using Snarf.Domain.Base;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using Snarf.Domain.Entities;

namespace Snarf.Persistence
{
    public class SnarfContext(DbContextOptions<SnarfContext> options) : IdentityDbContext<User>(options)
    {
        public DbSet<PrivateChatMessage> PrivateChatMessages { get; set; }
        public DbSet<PublicChatMessage> PublicChatMessages { get; set; }
        public DbSet<FavoriteChat> FavoriteChats { get; set; }
        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);
        }
    }
}