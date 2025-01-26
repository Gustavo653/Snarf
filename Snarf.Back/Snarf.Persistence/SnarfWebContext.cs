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
        public DbSet<BlockedUser> BlockedUsers { get; set; }
        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);


            modelBuilder.Entity<BlockedUser>()
                .HasOne(b => b.Blocker)
                .WithMany(u => u.BlockedUsers)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<BlockedUser>()
                .HasOne(b => b.Blocked)
                .WithMany(u => u.BlockedBy)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<FavoriteChat>()
                .HasOne(b => b.User)
                .WithMany(u => u.FavoriteChats)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<FavoriteChat>()
                .HasOne(b => b.ChatUser)
                .WithMany(u => u.FavoritedBy)
                .OnDelete(DeleteBehavior.Restrict);
        }
    }
}