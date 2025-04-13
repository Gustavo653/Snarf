using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using Snarf.Domain.Base;
using Snarf.Domain.Entities;

namespace Snarf.Persistence
{
    public class SnarfContext(DbContextOptions<SnarfContext> options) : IdentityDbContext<User>(options)
    {
        public DbSet<PrivateChatMessage> PrivateChatMessages { get; set; }
        public DbSet<PublicChatMessage> PublicChatMessages { get; set; }
        public DbSet<FavoriteChat> FavoriteChats { get; set; }
        public DbSet<BlockedUser> BlockedUsers { get; set; }
        public DbSet<VideoCallLog> VideoCallLogs { get; set; }
        public DbSet<Party> Parties { get; set; }
        public DbSet<PartyChatMessage> PartyChatMessages { get; set; }
        public DbSet<Place> Places { get; set; }
        public DbSet<PlaceChatMessage> PlaceChatMessages { get; set; }

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

            modelBuilder.Entity<Party>()
                .HasOne(p => p.Owner)
                .WithMany(u => u.OwnedParties)
                .HasForeignKey(p => p.OwnerId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<Party>()
                .HasMany(p => p.InvitedUsers)
                .WithMany(u => u.Invitations)
                .UsingEntity<Dictionary<string, object>>(
                    "PartyInvitedUsers",
                    j => j.HasOne<User>().WithMany().HasForeignKey("UserId"),
                    j => j.HasOne<Party>().WithMany().HasForeignKey("PartyId")
                );

            modelBuilder.Entity<Party>()
                .HasMany(p => p.ConfirmedUsers)
                .WithMany(u => u.ConfirmedParties)
                .UsingEntity<Dictionary<string, object>>(
                    "PartyConfirmedUsers",
                    j => j.HasOne<User>().WithMany().HasForeignKey("UserId"),
                    j => j.HasOne<Party>().WithMany().HasForeignKey("PartyId")
                );
        }
    }
}